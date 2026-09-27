import 'dart:io';
import 'dart:math';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

import 'package:torrid/core/services/debug/logging_service.dart';
import 'package:torrid/core/utils/file_relates.dart';
import 'package:torrid/core/utils/util.dart';

/// 统一的外部公共存储服务
///
/// 管理保存到系统公共相册 `/storage/emulated/0/Pictures/torrid/` 下各子目录的逻辑。
/// 各模块通过指定 [SubDir] 或自定义子目录来保存文件。
class PublicStorageService {
  PublicStorageService._();

  /// 外部公共存储根路径(用户可见的相册目录)
  static const String _publicRoot = '/storage/emulated/0/Pictures/torrid';

  /// 预定义子目录
  static const String dirComic = 'comic';
  static const String dirGallery = 'gallery';
  static const String dirApi = 'api';
  static const String dirBing = 'bing';

  /// 获取指定子目录的完整路径
  static String getSubDirPath(String subDir) => p.join(_publicRoot, subDir);

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

  // 通用保存

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

      final targetPath = p.join(getSubDirPath(subDir), safeFileName(fileName));
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

      final targetFile = File(
        p.join(getSubDirPath(subDir), safeFileName(fileName)),
      );

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

  // 便捷方法

  /// 把调用方给的文件名收敛成一个安全的**单段文件名**.
  ///
  /// 修的是这个历史 bug: 漫画导出把服务端来的 `comicName` 直接插进文件名
  /// (`"$comicName_第N章_..."`), 而 `comicName` 可能包含 `/` 这类路径分隔符,
  /// 轻则保存失败, 重则写到目标子目录之外.
  ///
  /// 这里是"文件名变成文件系统路径"的唯一出口, 所以再兜一层, 覆盖所有调用方
  /// (含把服务端文件名直接传进来的 gallery 保存路径);
  /// 全部被过滤后为空时给一个兜底名.
  static String safeFileName(String fileName) {
    final safe = sanitizeDirectoryName(fileName).trim();
    if (safe.isEmpty) {
      return generateFileName();
    }
    return safe;
  }

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
