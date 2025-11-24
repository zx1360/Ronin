import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:torrid/services/debug/logging_service.dart';

class IoService {
  static Directory? _externalStorageDir;

  static Future<Directory> get externalStorageDir async {
    _externalStorageDir ??= await getExternalStorageDirectory();
    return _externalStorageDir!;
  }

  // --------系统目录相关--------
  // 创建应用需要用到的所有目录.
  static Future<void> initDirs() async {
    final directory = await externalStorageDir;
    final dirs = ["img_storage/booklet", "img_storage/essay", "comics"];
    for (final dir in dirs) {
      await Directory(path.join(directory.path, dir)).create(recursive: true);
    }
  }

  // 删除目录下的所有内容但保留目录本身
  static Future<void> deleteDirectoryContents(Directory dir) async {
    if (!await dir.exists()) return;

    // 遍历目录中的所有内容
    await for (final entity in dir.list()) {
      if (entity is File) {
        // 删除文件
        await entity.delete();
      } else if (entity is Directory) {
        // 递归删除子目录
        await entity.delete(recursive: true);
      }
    }
    AppLogger().info("已清空'${dir.path}'目录下的所有内容.");
  }

  // 清除外部私有空间中的指定目录(包括本身)
  static Future<void> clearSpecificDirectory(String relativePath) async {
    try {
      // 获取应用外部私有存储根目录
      final externalDir = await IoService.externalStorageDir;

      // 构建目标目录的完整路径
      final targetDir = Directory(path.join(externalDir.path, relativePath));

      // 检查目录是否存在
      if (await targetDir.exists()) {
        // 递归删除该目录及其所有内容
        await targetDir.delete(recursive: true);
        AppLogger().info("已清除指定目录: ${targetDir.path}");
      } else {
        AppLogger().info("指定目录不存在: ${targetDir.path}");
      }
    } catch (e) {
      throw Exception("清除指定目录失败: $e");
    }
  }

  // --------文件内容相关--------
  // 读取外部私有空间的图片文件
  static Future<File?> getImageFile(String imgUrl) async {
    try {
      final externalDir = await IoService.externalStorageDir;
      final pureUrl = imgUrl.startsWith("/")
          ? imgUrl.replaceFirst("/", "")
          : imgUrl;
      final filePath = '${externalDir.path}/$pureUrl';
      final file = File(filePath);
      return await file.exists() ? file : null;
    } catch (e) {
      AppLogger().error('图片路径处理错误: $e');
      return null;
    }
  }
}
