/// Comic 模块的文件系统扫描服务
///
/// 提供本地漫画目录的扫描和元数据生成功能。
library;

import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/others/comic/models/chapter_info.dart';
import 'package:torrid/features/others/comic/models/comic_info.dart';
import 'package:torrid/features/others/comic/services/comic_servic.dart';
import 'package:torrid/features/others/comic/services/io_comic_service.dart';
import 'package:torrid/features/others/comic/services/io_image_service.dart';
import 'package:torrid/providers/progress/progress.dart';
import 'package:torrid/providers/progress/progress_provider.dart';
import 'package:torrid/core/services/io/io_service.dart';

part 'service_provider.g.dart';

/// 扫描漫画目录获取所有漫画和章节元数据
/// 
/// 遍历 `comics` 目录下的所有子目录，生成 [ComicInfo] 和 [ChapterInfo]。
@riverpod
Future<Map<String, dynamic>> allInfos(AllInfosRef ref) async {
  final comicInfos = <ComicInfo>[];
  final chapterInfos = <ChapterInfo>[];
  
  final externalDir = await IoService.externalStorageDir;
  final comicsDir = Directory("${externalDir.path}/comics");
  final comicsFolders = await comicsDir
      .list()
      .where((entity) => entity is Directory)
      .toList();

  final progressNotifier = ref.read(progressServiceProvider.notifier);
  progressNotifier.setProgress(
    Progress(
      current: 0,
      total: comicsFolders.length,
      currentMessage: "",
      message: "正在初始化漫画文件元数据...",
    ),
  );
  
  int counter = 0;
  for (final folder in comicsFolders) {
    final comicDir = folder as Directory;
    final comicName = comicDir.path.split(Platform.pathSeparator).last;
    progressNotifier.increaseProgress(
      current: counter,
      currentMessage: comicName,
    );
    counter++;

    // 生成漫画信息
    final comicInfo = await _buildComicInfo(comicDir, comicName);
    comicInfos.add(comicInfo);

    // 生成章节信息
    final chapters = await _buildChapterInfos(comicDir, comicInfo.id);
    chapterInfos.addAll(chapters);
  }
  
  ref.read(progressServiceProvider.notifier).resetStatus();
  
  return {
    "comicInfos": {for (final info in comicInfos) info.id: info},
    "chapterInfos": {for (final info in chapterInfos) info.id: info},
  };
}

/// 从目录构建漫画信息
Future<ComicInfo> _buildComicInfo(Directory comicDir, String comicName) async {
  final coverImage = await findFirstImage(comicDir);
  final stats = await countComicStats(comicDir);
  final chapterCount = stats.chapterCount;
  final imageCount = stats.imageCount;
  
  return ComicInfo.newOne(
    comicName: comicName,
    coverImage: coverImage,
    chapterCount: chapterCount,
    imageCount: imageCount,
  );
}

/// 从目录构建章节信息列表
Future<List<ChapterInfo>> _buildChapterInfos(
  Directory comicDir,
  String comicId,
) async {
  final chapterInfos = <ChapterInfo>[];
  
  final chapterDirs = await comicDir
      .list()
      .where((entity) => entity is Directory)
      .toList();
      
  chapterDirs.sort((a, b) {
    final aName = (a as Directory).path.split(Platform.pathSeparator).last;
    final bName = (b as Directory).path.split(Platform.pathSeparator).last;
    return getChapterIndex(aName).compareTo(getChapterIndex(bName));
  });

  for (final dir in chapterDirs) {
    final chapterDir = dir as Directory;
    final chapterName = chapterDir.path.split(Platform.pathSeparator).last;
    final imagesInChapter = await scanImages(chapterDir);

    final chapterInfo = ChapterInfo.newOne(
      comicId: comicId,
      chapterIndex: getChapterIndex(chapterName),
      dirName: chapterName,
      images: imagesInChapter,
    );
    chapterInfos.add(chapterInfo);
  }
  
  return chapterInfos;
}
