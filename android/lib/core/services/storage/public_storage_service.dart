import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:torrid/core/services/debug/logging_service.dart';
import 'package:torrid/core/services/io/io_service.dart';
import 'package:torrid/core/utils/file_relates.dart';
import 'package:torrid/core/utils/util.dart';

class SavedMedia {
  final Uri uri;
  final String location;

  const SavedMedia({required this.uri, required this.location});
}

class PublicStorageService {
  PublicStorageService._();

  static const _channel = MethodChannel('torrid/public_media');
  static const dirComic = 'comic';
  static const dirGallery = 'gallery';
  static const dirApi = 'api';
  static const dirBing = 'bing';

  static Future<SavedMedia?> saveBytes({
    required String subDir,
    required String fileName,
    required List<int> bytes,
    String? mimeType,
  }) async {
    if (bytes.isEmpty) throw const FormatException('媒体文件为空');
    return saveDownload(
      subDir: subDir,
      fileName: fileName,
      mimeType: mimeType,
      download: (target) async {
        await File(target).writeAsBytes(bytes, flush: true);
      },
    );
  }

  static Future<SavedMedia?> saveDownload({
    required String subDir,
    required String fileName,
    required Future<void> Function(String target) download,
    String? mimeType,
  }) async {
    final root = await IoService.temporaryDirectory('media_export');
    final work = await root.createTemp('export-');
    try {
      final source = File(path.join(work.path, 'source'));
      await download(source.path);
      return await copyFile(
        subDir: subDir,
        sourceFilePath: source.path,
        fileName: fileName,
        mimeType: mimeType,
      );
    } finally {
      try {
        await work.delete(recursive: true);
      } catch (error) {
        AppLogger().warning('清理媒体导出暂存失败: $error');
      }
    }
  }

  static Future<SavedMedia?> copyFile({
    required String subDir,
    required String sourceFilePath,
    String? fileName,
    String? mimeType,
  }) async {
    final name = fileName == null || fileName.isEmpty
        ? generateUniqueFileName('img', getFileExtension(sourceFilePath))
        : fileName;
    final arguments = {
      'path': sourceFilePath,
      'subDir': subDir,
      'fileName': name,
      'mimeType': mimeType,
    };
    Future<Map<String, dynamic>?> save() =>
        _channel.invokeMapMethod<String, dynamic>('saveFile', arguments);

    Map<String, dynamic>? saved;
    try {
      saved = await save();
    } on PlatformException catch (error) {
      if (error.code != 'storage_permission_required') {
        throw StateError(error.message ?? '媒体导出失败');
      }
      if (!await Permission.storage.request().isGranted) return null;
      saved = await save();
    }
    if (saved == null) throw StateError('系统未确认媒体导出成功');
    return SavedMedia(
      uri: Uri.parse(saved['uri'] as String),
      location: saved['location'] as String,
    );
  }

  static String generateUniqueFileName(String baseName, String extension) {
    final safeBase = sanitizeDirectoryName(baseName.replaceAll(' ', '_'));
    return '${safeBase}_${getTodayDateString()}_${generateFileName()}.$extension';
  }

  static String generateDateFileName(String baseName, String extension) {
    final safeBase = sanitizeDirectoryName(baseName.replaceAll(' ', '_'));
    return '${safeBase}_${getTodayDateString()}.$extension';
  }
}
