import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:torrid/services/debug/logging_service.dart';
import 'package:torrid/services/storage/prefs_service.dart';

import 'package:torrid/services/system/system_service.dart';

class IoService {
  // 创建应用需要用到的所有目录.
  // TODO: 优化点, 全局搜索"getExternalStorageDirectory();"
  // --------系统目录相关--------
  static Future<void> initDirs()async{
    // 获取应用外部私有存储目录（Android的getExternalFilesDir，iOS的Documents）
    // booklet/essay图片文件夹.
    final directory = await getExternalStorageDirectory();
    if (directory == null) return;
    final bookletImgDir = path.join(directory.path, "img_storage/booklet");
    final essayImgDir = path.join(directory.path, "img_storage/essay");

    // 确保目录存在
    await Directory(bookletImgDir).create(recursive: true);
    await Directory(essayImgDir).create(recursive: true);
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
      final externalDir = await getExternalStorageDirectory();
      if (externalDir == null) {
        throw Exception("无法获取应用外部私有存储目录");
      }
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

  // 将本地图片保存到外部共有空间
  static Future<bool> saveThisImage(
    String privateImagePath,
    String? filename,
  ) async {
    try {
      // TODO: 结合permission_handler.
      // 检查存储权限
      // var status = await Permission.storage.isGranted;
      // if (!status) {
      //   status = await Permission.storage.request().isGranted;
      //   if (!status) {
      //     // 权限被拒绝
      //     return false;
      //   }
      // }

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
        await SystemService.scanFile(targetFile.path);
      }

      return true;
    } catch (e) {
      // 捕获所有可能的异常
      AppLogger().error('保存图片失败: $e');
      return false;
    }
  }

  // GET请求图片并保存到安卓应用的外部私有空间
  static Future<void> saveFromRelativeUrls(
    List<String> urls,
    String relativeDir,
  ) async {
    try {
      await IoService.clearSpecificDirectory(relativeDir);
      // 获取应用的外部私有存储目录
      // 对于Android，这是位于外部存储的Android/data/[包名]/files/目录
      final externalDir = await getExternalStorageDirectory();
      if (externalDir == null) {
        throw Exception("无法获取应用外部私有存储目录");
      }

      // 创建目标文件所在的目录, 确保目录存在
      final targetDir = path.join(externalDir.path, relativeDir);
      final directory = Directory(targetDir);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // TODO: 在ApiHandler改为单例模式之后, 用它发送请求, 省去获重复取ip,port.
      final prefs = PrefsService().prefs;
      final pcIp = prefs.getString("PC_IP");
      final pcPort = prefs.getString("PC_PORT");
      // 请求图片
      for (final url in urls) {
        final response = await get(Uri.parse("http://$pcIp:$pcPort/static/$url"));
        if (response.statusCode != 200) {
          throw Exception('图片请求失败，状态码: ${response.statusCode}');
        }

        // 获取图片数据
        final Uint8List imageData = response.bodyBytes;
        final String fileName = path.basename(url);
        final String savePath = path.join(targetDir, fileName);

        // 将图片数据写入文件
        final File imageFile = File(savePath);
        await imageFile.writeAsBytes(imageData);
      }
    } catch (e) {
      throw Exception("保存到应用外部私有空间失败\n$e");
    }
  }




// --------其他--------
  // 提取文件扩展名
  static String _getFileExtension(String filePath) {
    int lastDotIndex = filePath.lastIndexOf('.');
    if (lastDotIndex != -1 && lastDotIndex < filePath.length - 1) {
      return filePath.substring(lastDotIndex + 1).toLowerCase();
    }
    return '';
  }

}
