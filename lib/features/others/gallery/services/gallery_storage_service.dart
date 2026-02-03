import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:torrid/core/services/debug/logging_service.dart';
import 'package:torrid/core/services/io/io_service.dart';

/// Gallery 文件存储服务 - 管理本地媒体文件的存储路径
/// 存储结构:
/// - /gallery/Media/yyyy-mm/...    原图
/// - /gallery/Thumbs/yyyy-mm/...   缩略图
/// - /gallery/Previews/yyyy-mm/... 预览图
class GalleryStorageService {
  static final GalleryStorageService _instance =
      GalleryStorageService._internal();
  factory GalleryStorageService() => _instance;
  GalleryStorageService._internal();

  static const String _galleryRoot = 'gallery';
  static const String _mediaDir = 'Media';
  static const String _thumbDir = 'Thumbs';
  static const String _previewDir = 'Previews';

  /// 获取 Gallery 根目录
  Future<Directory> get galleryRoot async {
    return IoService.ensureDirExists(_galleryRoot);
  }

  /// 初始化目录结构
  Future<void> initDirectories() async {
    await Future.wait([
      IoService.ensureDirExists('$_galleryRoot/$_mediaDir'),
      IoService.ensureDirExists('$_galleryRoot/$_thumbDir'),
      IoService.ensureDirExists('$_galleryRoot/$_previewDir'),
    ]);
    AppLogger().info('Gallery 存储目录初始化完成');
  }

  // ============ 路径转换 ============

  /// 从服务端相对路径转换为本地绝对路径 (原图)
  /// 服务端: "2008-08/filename.jpg" -> 本地: ".../gallery/Media/2008-08/filename.jpg"
  Future<String> getLocalMediaPath(String serverPath) async {
    final externalDir = await IoService.externalStorageDir;
    // 将反斜杠统一为正斜杠
    final normalizedPath = serverPath.replaceAll('\\', '/');
    return p.join(externalDir.path, _galleryRoot, _mediaDir, normalizedPath);
  }

  /// 从服务端相对路径转换为本地绝对路径 (缩略图)
  Future<String> getLocalThumbPath(String serverPath) async {
    final externalDir = await IoService.externalStorageDir;
    final normalizedPath = serverPath.replaceAll('\\', '/');
    return p.join(externalDir.path, _galleryRoot, _thumbDir, normalizedPath);
  }

  /// 从服务端相对路径转换为本地绝对路径 (预览图)
  Future<String> getLocalPreviewPath(String serverPath) async {
    final externalDir = await IoService.externalStorageDir;
    final normalizedPath = serverPath.replaceAll('\\', '/');
    return p.join(externalDir.path, _galleryRoot, _previewDir, normalizedPath);
  }

  // ============ 文件操作 ============

  /// 保存媒体文件到本地
  Future<File> saveMediaFile({
    required String serverPath,
    required List<int> bytes,
  }) async {
    final localPath = await getLocalMediaPath(serverPath);
    final file = File(localPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    return file;
  }

  /// 保存缩略图到本地
  Future<File> saveThumbFile({
    required String serverPath,
    required List<int> bytes,
  }) async {
    final localPath = await getLocalThumbPath(serverPath);
    final file = File(localPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    return file;
  }

  /// 保存预览图到本地
  Future<File> savePreviewFile({
    required String serverPath,
    required List<int> bytes,
  }) async {
    final localPath = await getLocalPreviewPath(serverPath);
    final file = File(localPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    return file;
  }

  /// 检查本地媒体文件是否存在
  Future<bool> mediaFileExists(String serverPath) async {
    final localPath = await getLocalMediaPath(serverPath);
    return File(localPath).exists();
  }

  /// 检查本地缩略图是否存在
  Future<bool> thumbFileExists(String serverPath) async {
    final localPath = await getLocalThumbPath(serverPath);
    return File(localPath).exists();
  }

  /// 获取本地媒体文件 (如果存在)
  Future<File?> getMediaFile(String serverPath) async {
    final localPath = await getLocalMediaPath(serverPath);
    final file = File(localPath);
    return await file.exists() ? file : null;
  }

  /// 获取本地缩略图文件 (如果存在)
  Future<File?> getThumbFile(String serverPath) async {
    final localPath = await getLocalThumbPath(serverPath);
    final file = File(localPath);
    return await file.exists() ? file : null;
  }

  /// 获取本地预览图文件 (如果存在)
  Future<File?> getPreviewFile(String serverPath) async {
    final localPath = await getLocalPreviewPath(serverPath);
    final file = File(localPath);
    return await file.exists() ? file : null;
  }

  /// 删除媒体文件及其缩略图/预览图
  Future<void> deleteMediaFiles({
    required String? filePath,
    required String? thumbPath,
    required String? previewPath,
  }) async {
    final futures = <Future>[];

    if (filePath != null) {
      final path = await getLocalMediaPath(filePath);
      final file = File(path);
      if (await file.exists()) {
        futures.add(file.delete());
      }
    }

    if (thumbPath != null) {
      final path = await getLocalThumbPath(thumbPath);
      final file = File(path);
      if (await file.exists()) {
        futures.add(file.delete());
      }
    }

    if (previewPath != null) {
      final path = await getLocalPreviewPath(previewPath);
      final file = File(path);
      if (await file.exists()) {
        futures.add(file.delete());
      }
    }

    await Future.wait(futures);
  }

  // ============ 统计信息 ============

  /// 获取存储统计信息
  Future<GalleryStorageStats> getStorageStats() async {
    final externalDir = await IoService.externalStorageDir;
    final galleryDir =
        Directory(p.join(externalDir.path, _galleryRoot));

    if (!await galleryDir.exists()) {
      return GalleryStorageStats(fileCount: 0, totalBytes: 0);
    }

    int fileCount = 0;
    int totalBytes = 0;

    await for (final entity
        in galleryDir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        fileCount++;
        totalBytes += await entity.length();
      }
    }

    return GalleryStorageStats(fileCount: fileCount, totalBytes: totalBytes);
  }

  /// 清空所有 Gallery 文件 (保留目录结构)
  Future<void> clearAllFiles() async {
    final externalDir = await IoService.externalStorageDir;
    final galleryDir = Directory(p.join(externalDir.path, _galleryRoot));

    if (await galleryDir.exists()) {
      await IoService.deleteDirectoryContents(galleryDir);
      // 重新创建目录结构
      await initDirectories();
    }
    AppLogger().info('Gallery 文件存储已清空');
  }

  /// 清理空目录
  Future<void> cleanupEmptyDirectories() async {
    final externalDir = await IoService.externalStorageDir;
    final galleryDir = Directory(p.join(externalDir.path, _galleryRoot));

    if (!await galleryDir.exists()) return;

    await _removeEmptyDirectories(galleryDir);
  }

  Future<void> _removeEmptyDirectories(Directory dir) async {
    // 递归处理子目录
    await for (final entity in dir.list()) {
      if (entity is Directory) {
        await _removeEmptyDirectories(entity);
      }
    }

    // 检查当前目录是否为空
    final contents = await dir.list().toList();
    if (contents.isEmpty) {
      // 不删除根目录
      final externalDir = await IoService.externalStorageDir;
      final galleryRootPath = p.join(externalDir.path, _galleryRoot);
      if (dir.path != galleryRootPath) {
        await dir.delete();
      }
    }
  }
}

/// 存储统计信息
class GalleryStorageStats {
  final int fileCount;
  final int totalBytes;

  const GalleryStorageStats({
    required this.fileCount,
    required this.totalBytes,
  });

  /// 格式化显示大小
  String get formattedSize {
    if (totalBytes < 1024) {
      return '$totalBytes B';
    } else if (totalBytes < 1024 * 1024) {
      return '${(totalBytes / 1024).toStringAsFixed(2)} KB';
    } else if (totalBytes < 1024 * 1024 * 1024) {
      return '${(totalBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }
}
