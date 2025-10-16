// 获取所有图片文件的path
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:torrid/features/others/comic/models/data_class.dart';

// 将目标目录下的所有图片文件按名称升序返回.
Future<List<String>> loadChapterImages(ChapterInfo info) async {
  try {
    final chapterDir = Directory(info.path);

    // 获取所有图片并按名称排序
    final imageFiles = await chapterDir
        .list()
        .where(
          (entity) =>
              entity is File &&
              [
                'jpg',
                'jpeg',
                'png',
                'gif',
              ].contains((entity).path.split('.').last.toLowerCase()),
        )
        .toList();

    // 按文件名排序（假设文件名是数字）
    imageFiles.sort((a, b) {
      final aName = (a as File).path
          .split(Platform.pathSeparator)
          .last
          .split('.')
          .first;
      final bName = (b as File).path
          .split(Platform.pathSeparator)
          .last
          .split('.')
          .first;
      return int.tryParse(aName)?.compareTo(int.tryParse(bName) ?? 0) ?? 0;
    });

    return imageFiles.map((file) => (file as File).path).toList();
  } catch (e) {
    throw Exception('加载图片失败: ${e.toString()}');
  }
}

// 获取图片尺寸
  Future<Size> getImageSize(String path) async {
    final bytes = await File(path).readAsBytes();
    final decodedImage = await decodeImageFromList(bytes);
    return Size(decodedImage.width.toDouble(), decodedImage.height.toDouble());
  }
