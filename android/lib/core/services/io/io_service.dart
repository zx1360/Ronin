import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:torrid/core/services/debug/logging_service.dart';

class IoService {
  static const _userDirectories = {
    'img_storage/booklet': 'booklet',
    'img_storage/essay': 'essay',
    'img_storage/chat': 'chat',
    'essay_drafts': 'essay_drafts',
    'preferences': 'preferences',
  };

  static String safePath(Directory root, String relativePath) {
    final parts = relativePath.split('/');
    if (relativePath.isEmpty ||
        relativePath.contains(RegExp(r'[\\:\x00]')) ||
        parts.any((part) => part.isEmpty || part == '.' || part == '..')) {
      throw FormatException('无效的相对路径: $relativePath');
    }
    final result = path.joinAll([root.path, ...parts]);
    if (!path.isWithin(root.path, result)) {
      throw FormatException('路径超出存储目录: $relativePath');
    }
    return result;
  }

  static Future<String> _userPath(String key) async {
    final relative = key.startsWith('/') ? key.substring(1) : key;
    for (final entry in _userDirectories.entries) {
      if (relative == entry.key || relative.startsWith('${entry.key}/')) {
        final root = Directory(
          path.join((await getApplicationSupportDirectory()).path, 'media'),
        );
        // 同步键保持兼容，磁盘目录不再绑定服务端的 img_storage 布局。
        return safePath(root, relative.replaceFirst(entry.key, entry.value));
      }
    }
    throw FormatException('未知的用户文件目录: $key');
  }

  static Future<Directory> userDirectory(String key) async =>
      Directory(await _userPath(key)).create(recursive: true);

  static Future<File> userFile(String key) async => File(await _userPath(key));

  static Future<Directory> offlineDirectory(String relativePath) async {
    final root = await getExternalStorageDirectory();
    if (root == null) throw const FileSystemException('离线存储不可用');
    return Directory(safePath(root, relativePath)).create(recursive: true);
  }

  static Future<File> offlineFile(String relativePath) async {
    final root = await getExternalStorageDirectory();
    if (root == null) throw const FileSystemException('离线存储不可用');
    return File(safePath(root, relativePath));
  }

  static Future<Directory> temporaryDirectory(String name) async => Directory(
    safePath(await getTemporaryDirectory(), name),
  ).create(recursive: true);

  static Future<File> writeAtomically(File target, List<int> bytes) async {
    if (bytes.isEmpty) throw const FormatException('文件内容为空');
    await target.parent.create(recursive: true);
    final work = await target.parent.createTemp('.write-');
    try {
      final staged = await File(
        path.join(work.path, 'data'),
      ).writeAsBytes(bytes, flush: true);
      return await staged.rename(target.path);
    } finally {
      await _cleanWork(work);
    }
  }

  static Future<String> importUserImage(String directory, File source) async {
    final extension = path.extension(source.path).toLowerCase();
    final key = '$directory/${const Uuid().v4()}$extension';
    final target = await userFile(key);
    await target.parent.create(recursive: true);
    final work = await target.parent.createTemp('.write-');
    try {
      final staged = await source.copy(path.join(work.path, 'data'));
      if (await staged.length() == 0) {
        throw const FormatException('图片文件为空');
      }
      await staged.rename(target.path);
      return key;
    } finally {
      await _cleanWork(work);
    }
  }

  static Future<void> _cleanWork(Directory directory) async {
    try {
      await directory.delete(recursive: true);
    } catch (error) {
      AppLogger().warning('清理文件暂存失败: $error');
    }
  }

  static Future<void> deleteUserFile(String key) async {
    final file = await userFile(key);
    if (await file.exists()) await file.delete();
  }

  static Future<void> deleteUserDirectory(String key) async {
    final directory = Directory(await _userPath(key));
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  static Future<void> deleteOfflineDirectory(String key) async {
    final root = await getExternalStorageDirectory();
    if (root == null) throw const FileSystemException('离线存储不可用');
    final directory = Directory(safePath(root, key));
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  static Future<File?> getImageFile(String key) async {
    try {
      final file = await userFile(key);
      return await file.exists() ? file : null;
    } catch (error) {
      AppLogger().warning('读取用户图片失败: $error');
      return null;
    }
  }
}
