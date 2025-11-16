import 'dart:io';

import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/others/comic/models/chapter_info.dart';
import 'package:torrid/features/others/comic/models/comic_info.dart';
import 'package:torrid/features/others/comic/models/comic_preference.dart';
import 'package:torrid/features/others/comic/provider/box_provider.dart';
import 'package:torrid/features/others/comic/services/comic_servic.dart';
import 'package:torrid/features/others/comic/services/io_comic_service.dart';
import 'package:torrid/services/io/io_service.dart';

part 'notifier_provider.g.dart';

class Cashier {
  final Box<ComicPreference> prefBox;
  final Box<ComicInfo> comicInfoBox;
  final Box<ChapterInfo> chapterInfoBox;

  Cashier({
    required this.prefBox,
    required this.comicInfoBox,
    required this.chapterInfoBox,
  });
}

@riverpod
class ComicService extends _$ComicService {
  @override
  Cashier build() {
    return Cashier(
      prefBox: ref.read(comicPrefBoxProvider),
      comicInfoBox: ref.read(comicInfoBoxProvider),
      chapterInfoBox: ref.read(chapterInfoBoxProvider),
    );
  }

  // 切换某篇随笔的偏好
  Future<void> putComicPref({required ComicPreference comicPref})async{
    state.prefBox.put(comicPref.comicId, comicPref);
  }

  // 刷新漫画信息.
  // TODO: 分离到serviceProvider, 然后接收entries, 只需.putAll()
  Future<void> refreshInfo() async {
    // # 获取comicInfo信息
    final externalDir = await IoService.externalStorageDir;
    final comicsDir = Directory("${externalDir.path}/comics");

    final comicsFolders = await comicsDir
        .list()
        .where((entity) => entity is Directory)
        .toList();

    await state.comicInfoBox.clear();
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
      // TODO: 后续改为.putAll(), 优化下.
      await state.comicInfoBox.put(comicInfo.id, comicInfo);

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

      await state.chapterInfoBox.clear();
      for (var dir in chapterDirs) {
        final chapterDir = dir as Directory;
        final chapterName = chapterDir.path.split(Platform.pathSeparator).last;

        final chapterInfo = ChapterInfo.newOne(
          comicId: comicInfo.id,
          chapterIndex: getChapterIndex(chapterName),
          dirName: chapterName,
          images: [],
        );
        await state.chapterInfoBox.put(chapterInfo.id, chapterInfo);
      }
    }
  }

  // 
}
