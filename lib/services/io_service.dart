import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class IoService {
  // 删除目录下的所有内容但保留目录本身
  static Future<void> deleteDirectoryContents(Directory dir) async {
    if (!await dir.exists()) return;

    // 遍历目录中的所有内容
    await for (final entity in dir.list()) {
      if (entity is File) {
        // 删除文件
        await entity.delete();
        print("已删除文件: ${entity.path}");
      } else if (entity is Directory) {
        // 递归删除子目录
        await entity.delete(recursive: true);
        print("已删除目录: ${entity.path}");
      }
    }
  }

  // 清除外部私有空间中的指定目录
  static Future<void> clearSpecificDirectory(String relativePath) async {
    try {
      // 获取应用外部私有存储根目录
      final externalDir = await getExternalStorageDirectory();
      if (externalDir == null) {
        throw Exception("无法获取应用外部私有存储目录");
      }

      // 构建目标目录的完整路径
      final targetDir = Directory(path.join(externalDir.path, relativePath));

      // 检查目录是否存在
      if (await targetDir.exists()) {
        // 递归删除该目录及其所有内容
        await targetDir.delete(recursive: true);
        print("已清除指定目录: ${targetDir.path}");
      } else {
        print("指定目录不存在: ${targetDir.path}");
      }
    } catch (e) {
      throw Exception("清除指定目录失败: $e");
    }
  }

  // 读取外部私有空间的图片文件
  static Future<File?> getImageFile(String imgUrl) async {
    try {
      final externalDir = await getExternalStorageDirectory();
      if (externalDir == null) {
        throw Exception("无法获取应用外部私有存储目录");
      }
      final pureUrl = imgUrl.startsWith("/")
          ? imgUrl.replaceFirst("/", "")
          : imgUrl;
      final filePath = '${externalDir.path}/$pureUrl';
      // print(filePath);
      final file = File(filePath);
      // print(file.exists());
      return await file.exists() ? file : null;
    } catch (e) {
      debugPrint('图片路径处理错误: $e');
      return null;
    }
  }

  // 将本地图片保存到外部共有空间
  static Future<bool> saveThisImage(
    String privateImagePath,
    String? filename,
  ) async {
    try {
      // 检查存储权限
      // var status = await Permission.storage.isGranted;
      // if (!status) {
      //   status = await Permission.storage.request().isGranted;
      //   if (!status) {
      //     // 权限被拒绝
      //     return false;
      //   }
      // }
      print("b");

      // 验证源文件是否存在
      File sourceFile = File(privateImagePath);
      if (!await sourceFile.exists()) {
        return false;
      }

      // 获取外部公共图片目录
      Directory? publicDir = Directory('/storage/emulated/0/Pictures/torrid');

      if (!await publicDir.exists()) {
        try {
          await publicDir.create(recursive: true);
        } catch (e) {
          return false;
        }
      }

      // 处理文件名
      String targetFileName;
      String fileExtension = _getFileExtension(sourceFile.path);

      if (filename != null && filename.isNotEmpty) {
        // 使用传入的文件名，确保包含扩展名
        targetFileName =
            fileExtension.isNotEmpty && !filename.endsWith('.$fileExtension')
            ? '$filename.$fileExtension'
            : filename;
      } else {
        // 生成随机防重文件名 (时间戳+随机数+扩展名)
        String timestamp = DateFormat('yyyyMMddHHmmss').format(DateTime.now());
        int randomNum = Random().nextInt(10000);
        targetFileName =
            'img_${timestamp}_$randomNum${fileExtension.isNotEmpty ? '.$fileExtension' : ''}';
      }
      print("a");

      // 生成目标文件路径
      File targetFile = File('${publicDir.path}/$targetFileName');

      // 如果目标文件已存在，先删除
      if (await targetFile.exists()) {
        await targetFile.delete();
      }

      // 复制文件
      await sourceFile.copy(targetFile.path);

      // 通知系统媒体库更新
      if (Platform.isAndroid) {
        await _scanFile(targetFile.path);
      }

      return true;
    } catch (e) {
      // 捕获所有可能的异常
      print('保存图片失败: $e');
      return false;
    }
  }

  // 提取文件扩展名
  static String _getFileExtension(String filePath) {
    int lastDotIndex = filePath.lastIndexOf('.');
    if (lastDotIndex != -1 && lastDotIndex < filePath.length - 1) {
      return filePath.substring(lastDotIndex + 1).toLowerCase();
    }
    return '';
  }

  // 通知Android系统扫描文件，使其在相册中可见
  static Future<void> _scanFile(String path) async {
    try {
      await Process.run('am', [
        'broadcast',
        '-a',
        'android.intent.action.MEDIA_SCANNER_SCAN_FILE',
        '-d',
        'file://$path',
      ]);
    } catch (e) {
      print('扫描文件失败: $e');
    }
  }
}
