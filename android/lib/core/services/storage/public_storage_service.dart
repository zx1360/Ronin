import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';

import 'package:torrid/core/services/debug/logging_service.dart';
import 'package:torrid/core/utils/file_relates.dart';
import 'package:torrid/core/utils/util.dart';

/// 统一的外部公共存储服务
///
/// 管理保存到 /storage/emulated/0/Pictures/torrid/ 下各子目录的逻辑。
/// 各模块通过指定 [SubDir] 或自定义子目录来保存文件。
class PublicStorageService {
  PublicStorageService._();

  /// 外部公共存储根路径
  static const String _publicRoot = '/storage/emulated/0/Pictures/torrid';

  /// 预定义子目录
  static const String dirComic = 'comic';
  static const String dirGallery = 'gallery';
  static const String dirApi = 'api';
  static const String dirBing = 'bing';

  /// 获取指定子目录的完整路径
  static String getSubDirPath(String subDir) => '$_publicRoot/$subDir';

  /// 确保存储权限并创建目录，返回是否成功
  static Future<bool> ensureStorageAccess(String subDir) async {
    final hasAccess = await _requestStoragePermission();
    if (!hasAccess) {
      AppLogger().warning('存储权限被拒绝');
      return false;
    }

    final dir = Directory(getSubDirPath(subDir));
    if (!await dir.exists()) {
      try {
        await dir.create(recursive: true);
      } catch (e) {
        AppLogger().error('创建公共目录失败: $e');
        return false;
      }
    }
    return true;
  }

  /// 请求存储权限
  static Future<bool> _requestStoragePermission() async {
    // 检查 MANAGE_EXTERNAL_STORAGE 是否已授权
    if (await Permission.manageExternalStorage.isGranted) {
      return true;
    }

    // 请求 MANAGE_EXTERNAL_STORAGE（Android 11+ 会跳转系统设置页）
    final result = await Permission.manageExternalStorage.request();
    if (result.isGranted) return true;

    // 如果被永久拒绝，尝试打开应用设置页让用户手动授权
    if (result.isPermanentlyDenied) {
      await openAppSettings();
      // 用户从设置页返回后重新检查
      return await Permission.manageExternalStorage.isGranted;
    }

    // 降级尝试普通存储权限（Android 10 以下）
    final storageResult = await Permission.storage.request();
    return storageResult.isGranted;
  }

  // ============ 通用保存 ============

  /// 将字节数据保存到公共目录
  ///
  /// [subDir] 子目录名（如 'comic'、'gallery'、'api'、'bing'）
  /// [fileName] 文件名（含扩展名）
  /// [bytes] 文件数据
  /// 返回保存的文件，失败返回 null
  static Future<File?> saveBytes({
    required String subDir,
    required String fileName,
    required List<int> bytes,
  }) async {
    try {
      if (!await ensureStorageAccess(subDir)) return null;

      final targetPath = '${getSubDirPath(subDir)}/$fileName';
      final file = File(targetPath);

      if (await file.exists()) {
        await file.delete();
      }

      await file.writeAsBytes(bytes);
      return file;
    } catch (e) {
      AppLogger().error('保存文件失败: $e');
      return null;
    }
  }

  /// 复制文件到公共目录
  ///
  /// [subDir] 子目录名
  /// [sourceFilePath] 源文件路径
  /// [fileName] 目标文件名（含扩展名），为空则自动生成
  static Future<File?> copyFile({
    required String subDir,
    required String sourceFilePath,
    String? fileName,
  }) async {
    try {
      if (!await ensureStorageAccess(subDir)) return null;

      final sourceFile = File(sourceFilePath);
      if (!await sourceFile.exists()) {
        AppLogger().error('源文件不存在: $sourceFilePath');
        return null;
      }

      if (fileName == null || fileName.isEmpty) {
        final ext = getFileExtension(sourceFile.path);
        final timestamp = DateFormat('yyyyMMddHHmmss').format(DateTime.now());
        final randomNum = Random().nextInt(10000);
        fileName =
            'img_${timestamp}_$randomNum${ext.isNotEmpty ? '.$ext' : ''}';
      }

      final targetFile = File('${getSubDirPath(subDir)}/$fileName');

      if (await targetFile.exists()) {
        await targetFile.delete();
      }

      await sourceFile.copy(targetFile.path);
      return targetFile;
    } catch (e) {
      AppLogger().error('复制文件失败: $e');
      return null;
    }
  }

  // ============ 特殊操作 ============

  /// 合并多张图片并保存到公共目录（在 isolate 中执行）
  ///
  /// [subDir] 子目录名
  /// [imagePaths] 图片路径列表
  /// [fileName] 目标文件名（不含扩展名，将保存为 PNG）
  static Future<bool> mergeAndSaveImages({
    required String subDir,
    required List<String> imagePaths,
    required String fileName,
  }) async {
    if (imagePaths.isEmpty || fileName.isEmpty) return false;

    try {
      if (!await ensureStorageAccess(subDir)) return false;

      final params = {
        'imagePaths': imagePaths,
        'outputPath': '${getSubDirPath(subDir)}/$fileName.png',
      };

      return await compute(_processAndMergeImages, params);
    } catch (e) {
      AppLogger().error('合并保存图片失败: $e');
      return false;
    }
  }

  /// isolate 中执行的图片合并
  static Future<bool> _processAndMergeImages(
      Map<String, dynamic> params) async {
    final imagePaths = params['imagePaths'] as List<dynamic>;
    final outputPath = params['outputPath'] as String;

    List<img.Image> images = [];
    int width = 0;
    int totalHeight = 0;

    for (final path in imagePaths) {
      final imageFile = File(path as String);
      if (!await imageFile.exists()) return false;
      final image = img.decodeImage(await imageFile.readAsBytes())!;
      images.add(image);
      if (width == 0) {
        width = image.width;
      } else if (image.width != width) {
        return false;
      }
      totalHeight += image.height;
    }

    final mergedImage = img.Image(width: width, height: totalHeight);
    int currentHeight = 0;
    for (final image in images) {
      img.compositeImage(mergedImage, image, dstX: 0, dstY: currentHeight);
      currentHeight += image.height;
    }

    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(img.encodePng(mergedImage));
    return true;
  }

  // ============ 便捷方法 ============

  /// 生成带时间戳的唯一文件名
  ///
  /// [baseName] 基础名称
  /// [extension] 扩展名（不含点号）
  static String generateUniqueFileName(String baseName, String extension) {
    final safeBase = sanitizeDirectoryName(baseName.replaceAll(' ', '_'));
    final dateStr = getTodayDateString();
    final randomId = generateFileName();
    return '${safeBase}_${dateStr}_$randomId.$extension';
  }

  /// 生成日期文件名（不含随机后缀）
  ///
  /// [baseName] 基础名称
  /// [extension] 扩展名（不含点号）
  static String generateDateFileName(String baseName, String extension) {
    final safeBase = sanitizeDirectoryName(baseName.replaceAll(' ', '_'));
    final dateStr = getTodayDateString();
    return '${safeBase}_$dateStr.$extension';
  }
}
