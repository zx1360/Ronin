import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:torrid/core/services/debug/logging_service.dart';

/// 下载完成后替换目录；数据导入失败时恢复旧目录。
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
    var movedPrevious = false;
    var installed = false;
    try {
      if (await target.exists()) {
        await target.rename(previous.path);
        movedPrevious = true;
      }
      await staged.rename(target.path);
      installed = true;
      await writeData();
    } catch (error) {
      try {
        if (installed) await target.rename(staged.path);
        if (movedPrevious) await previous.rename(target.path);
      } catch (restoreError) {
        _keepBackup = true;
        throw FileSystemException(
          '恢复失败，旧文件保留在 ${previous.path}: $error; $restoreError',
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
