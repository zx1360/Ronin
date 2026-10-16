import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:torrid/core/services/debug/logging_service.dart';

/// 逐文件安装下载图片；导入失败时恢复被覆盖的文件。
class TransferFiles {
  TransferFiles._(this.target, this.work, this.staged);

  final Directory target;
  final Directory work;
  final Directory staged;
  bool _keepBackup = false;

  static Future<TransferFiles> create(Directory target) async {
    await target.parent.create(recursive: true);
    final work = await target.parent.createTemp('.sync-');
    final staged = await Directory(p.join(work.path, 'images')).create();
    return TransferFiles._(target, work, staged);
  }

  Future<void> apply(Future<void> Function() writeData) async {
    final previous = Directory(p.join(work.path, 'previous'));
    final undo = <(File, File)>[];
    try {
      final downloads = await staged
          .list(recursive: true)
          .where((e) => e is File)
          .cast<File>()
          .toList();
      for (final source in downloads) {
        final relative = p.relative(source.path, from: staged.path);
        final dest = File(p.join(target.path, relative));
        await dest.parent.create(recursive: true);
        final type = await FileSystemEntity.type(dest.path, followLinks: false);
        if (type != FileSystemEntityType.notFound) {
          if (type != FileSystemEntityType.file) {
            throw FileSystemException('图片目标不是普通文件', dest.path);
          }
          final backup = File(p.join(previous.path, relative));
          await backup.parent.create(recursive: true);
          await dest.rename(backup.path);
          undo.add((backup, dest));
        }
        await source.rename(dest.path);
        undo.add((dest, source));
      }
      await writeData();
    } catch (error) {
      final failures = <Object>[];
      for (final (source, dest) in undo.reversed) {
        try {
          await dest.parent.create(recursive: true);
          await source.rename(dest.path);
        } catch (restoreError) {
          failures.add(restoreError);
        }
      }
      if (failures.isNotEmpty) {
        _keepBackup = true;
        throw FileSystemException(
          '恢复失败，旧文件保留在 ${previous.path}: $error; $failures',
        );
      }
      rethrow;
    }
  }

  Future<void> dispose() async {
    if (_keepBackup) return;
    try {
      await work.delete(recursive: true);
    } catch (e) {
      AppLogger().warning('清理传输暂存目录失败: $e');
    }
  }
}
