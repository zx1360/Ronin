import 'dart:io';

import 'package:torrid/services/debug/logging_service.dart';

// ----comic_page.dart
// 查找目录中的第一张图片
Future<File?> findFirstImage(Directory dir) async {
  try {
    // 递归查找第一个图片文件
    await for (var entity in dir.list(recursive: true)) {
      if (entity is File) {
        final extension = entity.path.split('.').last.toLowerCase();
        if (['jpg', 'jpeg', 'png', 'gif'].contains(extension)) {
          return entity;
        }
      }
    }
  } catch (e) {
    AppLogger().error("查找封面图失败: $e");
  }
  return null;
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

// 计算总图片数量
Future<int> countTotalImages(Directory comicDir) async {
  int count = 0;
  try {
    await for (var entity in comicDir.list(recursive: true)) {
      if (entity is File) {
        final extension = entity.path.split('.').last.toLowerCase();
        if (['jpg', 'jpeg', 'png', 'gif'].contains(extension)) {
          count++;
        }
      }
    }
  } catch (e) {
    AppLogger().error("计算图片数失败: $e");
  }
  return count;
}

// comic_detail.dart
// 从章节名称中提取章节号
int extractChapterNumber(String chapterName) {
  // 确保章节名格式为 "数字_章节名"
  final parts = chapterName.split('_');
  if (parts.isNotEmpty) {
    return int.tryParse(parts[0]) ?? 0;
  }
  return 0;
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
