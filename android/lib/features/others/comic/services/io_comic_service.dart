import 'dart:io';

import 'package:torrid/core/services/debug/logging_service.dart';

// ----comic_page.dart
// 查找目录中的第一张图片
Future<String> findFirstImage(Directory dir) async {
  try {
    // 递归查找第一个图片文件
    await for (var entity in dir.list(recursive: true)) {
      if (entity is File) {
        final extension = entity.path.split('.').last.toLowerCase();
        if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension)) {
          return entity.path;
        }
      }
    }
  } catch (e) {
    AppLogger().error("查找封面图失败: $e");
  }
  return "";
}

// 计算章节数量
Future<int> countChapters(Directory comicDir) async {
  try {
    final chapters = await comicDir
        .list()
        .where((entity) => entity is Directory)
        .toList();
    return chapters.length;
  } catch (e) {
    AppLogger().error("计算章节数失败: $e");
    return 0;
  }
}

/// 一次遍历同时获取章节数量和总图片数量
/// 返回 (chapterCount, imageCount)
Future<({int chapterCount, int imageCount})> countComicStats(Directory comicDir) async {
  int chapterCount = 0;
  int imageCount = 0;
  const imageExtensions = {'jpg', 'jpeg', 'png', 'gif', 'webp'};
  
  try {
    await for (var entity in comicDir.list()) {
      if (entity is Directory) {
        chapterCount++;
        // 统计该章节目录下的图片
        await for (var file in entity.list()) {
          if (file is File) {
            final extension = file.path.split('.').last.toLowerCase();
            if (imageExtensions.contains(extension)) {
              imageCount++;
            }
          }
        }
      }
    }
  } catch (e) {
    AppLogger().error("统计漫画信息失败: $e");
  }
  return (chapterCount: chapterCount, imageCount: imageCount);
}

// 计算章节图片数量
Future<int> countChapterImages(Directory chapterDir) async {
  int count = 0;
  try {
    await for (var entity in chapterDir.list()) {
      if (entity is File) {
        final extension = entity.path.split('.').last.toLowerCase();
        if (['jpg', 'jpeg', 'png', 'gif'].contains(extension)) {
          count++;
        }
      }
    }
  } catch (e) {
    AppLogger().error("计算章节图片数失败: $e");
  }
  return count;
}
