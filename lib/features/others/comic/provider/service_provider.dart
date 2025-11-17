import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/others/comic/models/chapter_info.dart';
import 'package:torrid/features/others/comic/models/comic_info.dart';
import 'package:torrid/features/others/comic/services/comic_servic.dart';
import 'package:torrid/features/others/comic/services/io_comic_service.dart';
import 'package:torrid/services/io/io_service.dart';

part 'service_provider.g.dart';

@riverpod
Future<Map<String, dynamic>> initialInfos(InitialInfosRef ref) async {
  final List<ComicInfo> comicInfos = [];
  final List<ChapterInfo> chapterInfos = [];
  // # 获取comicInfo信息
  final externalDir = await IoService.externalStorageDir;
  final comicsDir = Directory("${externalDir.path}/comics");

  final comicsFolders = await comicsDir
      .list()
      .where((entity) => entity is Directory)
      .toList();

  for (var folder in comicsFolders) {
    final comicDir = folder as Directory;
    final comicName = comicDir.path.split(Platform.pathSeparator).last;

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

      final chapterInfo = ChapterInfo.newOne(
        comicId: comicInfo.id,
        chapterIndex: getChapterIndex(chapterName),
        dirName: chapterName,
        images: [],
      );
      chapterInfos.add(chapterInfo);
    }
  }
  return {
    "comicInfos": {for (final info in comicInfos) info.id: info},
    "chapterInfos": {for (final info in chapterInfos) info.id: info},
  };
}
