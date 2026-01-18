/// Comic 模块的文件系统扫描服务
///
/// 提供本地漫画目录的扫描和元数据生成功能。
library;

import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/others/comic/models/chapter_info.dart';
import 'package:torrid/features/others/comic/models/comic_info.dart';
import 'package:torrid/features/others/comic/provider/box_provider.dart';
import 'package:torrid/features/others/comic/provider/status_provider.dart';
import 'package:torrid/features/others/comic/services/comic_servic.dart';
import 'package:torrid/features/others/comic/services/io_comic_service.dart';
import 'package:torrid/features/others/comic/services/io_image_service.dart';
import 'package:torrid/providers/progress/progress.dart';
import 'package:torrid/providers/progress/progress_provider.dart';
import 'package:torrid/core/services/io/io_service.dart';

part 'service_provider.g.dart';

// ============================================================================
// 全量扫描
// ============================================================================

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

// ============================================================================
// 增量扫描
// ============================================================================

/// 获取需要删除的漫画记录
/// 
/// 返回 coverImage 文件不存在的漫画及其关联数据。
@riverpod
Future<Map<String, dynamic>> deletedInfos(DeletedInfosRef ref) async {
  final deletedComics = ref
      .read(comicInfosProvider)
      .where((info) => !File(info.coverImage).existsSync())
      .map((info) => info.id)
      .toList();
      
  final deletedChapterInfos = (await ref.read(chapterInfoStreamProvider.future))
      .where((info) => deletedComics.contains(info.comicId))
      .map((info) => info.id)
      .toList();
      
  final prefBox = ref.read(comicPrefBoxProvider);
  final deletedPrefs = deletedComics
      .map((comicId) => prefBox.get(comicId)?.comicId)
      .whereType<String>()
      .toList();
      
  return {
    "comics": deletedComics,
    "chapters": deletedChapterInfos,
    "prefs": deletedPrefs,
  };
}

/// 扫描未记录的新漫画目录
/// 
/// 只处理尚未在数据库中的漫画目录。
@riverpod
Future<Map<String, dynamic>> newInfos(NewInfosRef ref) async {
  final comicInfos = <ComicInfo>[];
  final chapterInfos = <ChapterInfo>[];
  
  final externalDir = await IoService.externalStorageDir;
  final comicsDir = Directory("${externalDir.path}/comics");
  final comicsFolders = await comicsDir
      .list()
      .where((entity) => entity is Directory)
      .toList();

  // 获取已记录的漫画名称
  final existingNames = ref
      .read(comicInfosProvider)
      .map((info) => info.comicName)
      .toSet();

  // 统计需要处理的数量
  final newFolders = comicsFolders
      .where((folder) {
        final name = (folder as Directory).path.split(Platform.pathSeparator).last;
        return !existingNames.contains(name);
      })
      .toList();

  final progressNotifier = ref.read(progressServiceProvider.notifier);
  progressNotifier.setProgress(
    Progress(
      current: 0,
      total: newFolders.length,
      currentMessage: "",
      message: "正在初始化漫画文件元数据...",
    ),
  );
  
  int counter = 0;
  for (final folder in newFolders) {
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

// ============================================================================
// 辅助方法
// ============================================================================

/// 从目录构建漫画信息
Future<ComicInfo> _buildComicInfo(Directory comicDir, String comicName) async {
  final coverImage = await findFirstImage(comicDir);
  final chapterCount = await countChapters(comicDir);
  final imageCount = await countTotalImages(comicDir);
  
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
