import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/others/comic/models/chapter_info.dart';
import 'package:torrid/features/others/comic/models/comic_info.dart';
import 'package:torrid/features/others/comic/provider/status_provider.dart';
import 'package:torrid/features/others/comic/services/comic_servic.dart';
import 'package:torrid/features/others/comic/services/io_comic_service.dart';
import 'package:torrid/features/others/comic/services/io_image_service.dart';
import 'package:torrid/providers/progress/progress.dart';
import 'package:torrid/providers/progress/progress_provider.dart';
import 'package:torrid/services/io/io_service.dart';

part 'service_provider.g.dart';

// 读取本地目录, 初始化漫画、章节、图片信息.
@riverpod
Future<Map<String, dynamic>> initialInfos(
  InitialInfosRef ref, {
  required bool onlyNew,
}) async {
  final List<ComicInfo> comicInfos = [];
  final List<ChapterInfo> chapterInfos = [];
  // # 获取comicInfo信息
  final externalDir = await IoService.externalStorageDir;
  final comicsDir = Directory("${externalDir.path}/comics");

  final comicsFolders = await comicsDir
      .list()
      .where((entity) => entity is Directory)
      .toList();
  // 是否只作增量刷新 (allIncluded)
  final alreadyIncludedDirs = [];
  if (onlyNew) {
    alreadyIncludedDirs.addAll(
      ref.read(comicInfosProvider).map((info) => info.comicName).toList(),
    );
  }

  // 进度条provider方法.
  final progressNotifier = ref.read(progressServiceProvider.notifier);
  int todoCounter = comicsFolders.length;
  if (onlyNew) {
    todoCounter = 0;
    for (var folder in comicsFolders) {
      final comicDir = folder as Directory;
      final comicName = comicDir.path.split(Platform.pathSeparator).last;
      if (onlyNew && alreadyIncludedDirs.contains(comicName)) {
        continue;
      }
      todoCounter++;
    }
  }
  progressNotifier.setProgress(
    Progress(
      current: 0,
      total: todoCounter,
      currentMessage: "",
      message: "正在初始化漫画文件元数据...",
    ),
  );
  int counter = 0;
  for (var folder in comicsFolders) {
    final comicDir = folder as Directory;
    final comicName = comicDir.path.split(Platform.pathSeparator).last;
    if (onlyNew && alreadyIncludedDirs.contains(comicName)) {
      continue;
    }
    progressNotifier.increaseProgress(
      current: counter,
      currentMessage: comicName,
    );
    counter++;

    File? coverImage = await findFirstImage(comicDir);
    final chapterCount = await countChapters(comicDir);
    final imageCount = await countTotalImages(comicDir);
    final comicInfo = ComicInfo.newOne(
      comicName: comicName,
      coverImage: coverImage?.path ?? "",
      chapterCount: chapterCount,
      imageCount: imageCount,
    );
    comicInfos.add(comicInfo);

    // # 获取chapterInfo信息
    // 列出所有章节文件夹并排序
    final chapterDirs = await comicDir
        .list()
        .where((entity) => entity is Directory)
        .toList();
    chapterDirs.sort((a, b) {
      final aName = (a as Directory).path.split(Platform.pathSeparator).last;
      final bName = (b as Directory).path.split(Platform.pathSeparator).last;
      return getChapterIndex(aName).compareTo(getChapterIndex(bName));
    });

    for (var dir in chapterDirs) {
      final chapterDir = dir as Directory;
      final chapterName = chapterDir.path.split(Platform.pathSeparator).last;
      final imagesInChapter = await scanImages(chapterDir);

      final chapterInfo = ChapterInfo.newOne(
        comicId: comicInfo.id,
        chapterIndex: getChapterIndex(chapterName),
        dirName: chapterName,
        images: imagesInChapter,
      );
      chapterInfos.add(chapterInfo);
    }
  }
  return {
    "comicInfos": {for (final info in comicInfos) info.id: info},
    "chapterInfos": {for (final info in chapterInfos) info.id: info},
  };
}
