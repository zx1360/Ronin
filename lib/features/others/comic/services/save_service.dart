import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:image/image.dart' as img;

import 'package:torrid/core/services/debug/logging_service.dart';
import 'package:torrid/core/utils/util.dart';

class ComicSaverService {
  static String publicPath = '/storage/emulated/0/Pictures/torrid';

  // # 翻页漫画的某页保存到外部空间
  static Future<bool> saveFlipImageToPublic(
    String privateImagePath,
    String filename,
  ) async {
    try {
      // TODO: 结合permission_handler.
      File sourceFile = File(privateImagePath);

      // 获取外部公共图片目录
      Directory? publicDir = Directory(publicPath);

      if (!await publicDir.exists()) {
        try {
          await publicDir.create(recursive: true);
        } catch (e) {
          return false;
        }
      }

      // 处理文件名
      String fileExtension = getFileExtension(sourceFile.path);

      if (filename.isEmpty) {
        // 生成随机防重文件名 (时间戳+随机数+扩展名)
        String timestamp = DateFormat('yyyyMMddHHmmss').format(DateTime.now());
        int randomNum = Random().nextInt(10000);
        filename =
            'img_${timestamp}_$randomNum${fileExtension.isNotEmpty ? '.$fileExtension' : ''}';
      }

      // 生成目标文件路径
      File targetFile = File('$publicPath/$filename');

      // 如果目标文件已存在，先删除
      if (await targetFile.exists()) {
        await targetFile.delete();
      }

      // 复制文件
      await sourceFile.copy(targetFile.path);

      return true;
    } catch (e) {
      // 捕获所有可能的异常
      AppLogger().error('保存图片失败: $e');
      return false;
    }
  }

  // # 图片合并的耗时操作
  static Future<bool> _processAndSaveImages(Map<String, dynamic> params) async {
    final imagePaths = params['imagePaths'];
    final filename = params['filename'];
    // 获取外部公共图片目录
    Directory? publicDir = Directory(publicPath);
    if (!await publicDir.exists()) {
      try {
        await publicDir.create(recursive: true);
      } catch (e) {
        return false;
      }
    }

    // 1.加载所有图片并获取宽高.
    List<img.Image> images = [];
    int width = 0;
    int totalHeight = 0;
    for (String path in imagePaths) {
      File imageFile = File(path);
      if (!await imageFile.exists()) return false;
      img.Image image = img.decodeImage(await imageFile.readAsBytes())!;
      images.add(image);
      if (width == 0) {
        width = image.width;
      } else if (image.width != width) {
        return false;
      }
      totalHeight += image.height;
    }
    // 绘制图片.
    img.Image mergedImage = img.Image(width: width, height: totalHeight);
    int currentHeight = 0;
    for (img.Image image in images) {
      img.compositeImage(mergedImage, image, dstX: 0, dstY: currentHeight);
      currentHeight += image.height;
    }
    // 保存
    File outputFile = File('$publicPath/$filename.png');
    await outputFile.writeAsBytes(img.encodePng(mergedImage));
    return true;
  }

  // 下拉漫画合并保存（对外暴露的方法）
  static Future<bool> saveScrollImagesToPublic(
    List<String> imagePaths,
    String filename,
  ) async {
    if (imagePaths.isEmpty || filename.isEmpty) return false;

    try {
      // 1. 包装需要传递给 compute 的参数（只能传1个参数，用Map包装多个值）
      final params = {
        'imagePaths': imagePaths,
        'filename': filename,
      };

      // 2. 使用 compute 执行耗时操作（回调函数必须是顶级函数）
      bool result = await compute(_processAndSaveImages, params);
      return result;
    } catch (e) {
      AppLogger().error('保存图片失败: $e');
      return false;
    }
  }
}
