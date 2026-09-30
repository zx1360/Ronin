/// Comic 模块的核心业务逻辑服务
///
/// 提供阅读偏好管理与元数据刷新等功能。
library;

import 'dart:io';

import 'package:hive/hive.dart';
import 'package:path/path.dart' as path;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/comic/models/chapter_info.dart';
import 'package:torrid/features/comic/models/comic_info.dart';
import 'package:torrid/features/comic/models/comic_preference.dart';
import 'package:torrid/features/comic/providers/box_provider.dart';
import 'package:torrid/features/comic/providers/service_provider.dart';
import 'package:torrid/features/comic/providers/status_provider.dart';
import 'package:torrid/features/comic/services/comic_servic.dart';
import 'package:torrid/features/comic/services/io_comic_service.dart';
import 'package:torrid/features/comic/services/io_image_service.dart';
import 'package:torrid/core/services/io/io_service.dart';

part 'notifier_provider.g.dart';

/// Comic 模块的数据仓库
///
/// 封装对 [ComicPreference]、[ComicInfo]、[ChapterInfo] 三个 Box 的访问。
class ComicRepository {
  final Box<ComicPreference> prefBox;
  final Box<ComicInfo> comicInfoBox;
  final Box<ChapterInfo> chapterInfoBox;

  const ComicRepository({
    required this.prefBox,
    required this.comicInfoBox,
    required this.chapterInfoBox,
  });
}

/// Comic 模块的核心服务
///
/// 提供以下功能：
/// - 阅读偏好管理
/// - 元数据刷新
@riverpod
class ComicService extends _$ComicService {
  @override
  ComicRepository build() {
    return ComicRepository(
      prefBox: ref.read(comicPrefBoxProvider),
      comicInfoBox: ref.read(comicInfoBoxProvider),
      chapterInfoBox: ref.read(chapterInfoBoxProvider),
    );
  }

  /// 保存漫画阅读偏好
  Future<void> putComicPref({required ComicPreference comicPref}) async {
    await state.prefBox.put(comicPref.comicId, comicPref);
    ref.invalidate(comicPrefWithComicIdProvider);
  }

  /// 修改漫画阅读偏好
  Future<void> modifyComicPref({
    required String comicId,
    int? chapterIndex,
    @Deprecated('保留仅为兼容旧数据') int? pageIndex,
    bool? isFlipMode,
  }) async {
    final comicPref = ref.read(comicPrefWithComicIdProvider(comicId: comicId));
    await state.prefBox.put(
      comicPref.comicId,
      comicPref.copyWith(
        chapterIndex: chapterIndex,
        // ignore: deprecated_member_use_from_same_package
        pageIndex: pageIndex,
        flipReading: isFlipMode,
      ),
    );
    ref.invalidate(comicPrefWithComicIdProvider);
  }

  /// 用服务器数据同步更新本地漫画各字段
  ///
  /// 仅更新服务器侧维护的字段（is_public / readed / chapter_count / image_count），
  /// 不覆盖本地持有的封面路径和 ID。
  Future<void> syncFieldsFromServer(ComicInfo serverComic) async {
    final localComic = state.comicInfoBox.get(serverComic.id);
    if (localComic == null) return;

    await state.comicInfoBox.put(
      serverComic.id,
      localComic.copyWith(
        isPublic: serverComic.isPublic,
        readed: serverComic.readed,
        chapterCount: serverComic.chapterCount,
        imageCount: serverComic.imageCount,
      ),
    );
  }

  /// 刷新所有漫画元数据（完全重建）
  Future<void> refreshInfosAll() async {
    final infos = await ref.read(allInfosProvider.future);
    await state.comicInfoBox.clear();
    await state.chapterInfoBox.clear();

    await state.comicInfoBox.putAll(
      infos['comicInfos'] as Map<dynamic, ComicInfo>,
    );
    await state.chapterInfoBox.putAll(
      infos['chapterInfos'] as Map<dynamic, ChapterInfo>,
    );
  }

  /// 增量刷新元数据（只处理变动）
  ///
  /// 以章节为最小粒度进行增量更新：
  /// - 删除本地目录已不存在的漫画及其章节
  /// - 对仍存在的漫画，比对并更新章节增删改
  /// - 新发现的漫画按全量方式入库
  Future<void> refreshChanged() async {
    final externalDir = await IoService.externalStorageDir;
    final comicsDir = Directory(path.join(externalDir.path, 'comics'));

    if (!await comicsDir.exists()) {
      await state.prefBox.clear();
      await state.comicInfoBox.clear();
      await state.chapterInfoBox.clear();
      return;
    }

    final comicEntities = await comicsDir
        .list()
        .where((entity) => entity is Directory)
        .toList();
    final comicDirs = comicEntities.cast<Directory>();

    final existingComics = state.comicInfoBox.values.toList();
    final existingComicByName = {
      for (final comic in existingComics) comic.comicName: comic,
    };

    final comicNamesOnDisk = comicDirs
        .map((dir) => dir.path.split(Platform.pathSeparator).last)
        .toSet();

    final deletedComicIds = existingComics
        .where((comic) => !comicNamesOnDisk.contains(comic.comicName))
        .map((comic) => comic.id)
        .toList();

    if (deletedComicIds.isNotEmpty) {
      await state.prefBox.deleteAll(deletedComicIds);
      await state.comicInfoBox.deleteAll(deletedComicIds);

      final chapterIdsToDelete = state.chapterInfoBox.values
          .where((chapter) => deletedComicIds.contains(chapter.comicId))
          .map((chapter) => chapter.id)
          .toList();
      if (chapterIdsToDelete.isNotEmpty) {
        await state.chapterInfoBox.deleteAll(chapterIdsToDelete);
      }
    }

    final existingChapterByComic = <String, Map<String, ChapterInfo>>{};
    for (final chapter in state.chapterInfoBox.values) {
      final chapterMap = existingChapterByComic.putIfAbsent(
        chapter.comicId,
        () => <String, ChapterInfo>{},
      );
      chapterMap[chapter.dirName] = chapter;
    }

    final comicsToUpsert = <String, ComicInfo>{};
    final chaptersToUpsert = <String, ChapterInfo>{};
    final chapterIdsToDelete = <String>[];

    for (final comicDir in comicDirs) {
      final comicName = comicDir.path.split(Platform.pathSeparator).last;
      final existingComic = existingComicByName[comicName];
      final comicId =
          existingComic?.id ??
          ComicInfo.newOne(
            comicName: comicName,
            coverImage: '',
            chapterCount: 0,
            imageCount: 0,
          ).id;

      final chapterEntities = await comicDir
          .list()
          .where((entity) => entity is Directory)
          .toList();
      final chapterDirs = chapterEntities.cast<Directory>();
      chapterDirs.sort((a, b) {
        final aName = a.path.split(Platform.pathSeparator).last;
        final bName = b.path.split(Platform.pathSeparator).last;
        return getChapterIndex(aName).compareTo(getChapterIndex(bName));
      });

      final existingChapters = existingChapterByComic[comicId] ?? {};
      final seenChapterNames = <String>{};

      int imageCount = 0;
      String coverImage = '';

      for (final chapterDir in chapterDirs) {
        final chapterName = chapterDir.path.split(Platform.pathSeparator).last;
        final chapterIndex = getChapterIndex(chapterName);
        seenChapterNames.add(chapterName);

        final images = await scanImages(chapterDir);
        imageCount += images.length;

        if (coverImage.isEmpty && images.isNotEmpty) {
          coverImage = images.first['path']?.toString() ?? '';
        }

        final existingChapter = existingChapters[chapterName];
        if (existingChapter != null) {
          chaptersToUpsert[existingChapter.id] = existingChapter.copyWith(
            chapterIndex: chapterIndex,
            dirName: chapterName,
            images: images,
            imageCount: images.length,
          );
        } else {
          final chapterInfo = ChapterInfo.newOne(
            comicId: comicId,
            chapterIndex: chapterIndex,
            dirName: chapterName,
            images: images,
            imageCount: images.length,
          );
          chaptersToUpsert[chapterInfo.id] = chapterInfo;
        }
      }

      for (final entry in existingChapters.entries) {
        if (!seenChapterNames.contains(entry.key)) {
          chapterIdsToDelete.add(entry.value.id);
        }
      }

      if (coverImage.isEmpty) {
        coverImage = await findFirstImage(comicDir);
      }

      final comicInfo = existingComic != null
          ? existingComic.copyWith(
              coverImage: coverImage.isNotEmpty
                  ? coverImage
                  : existingComic.coverImage,
              chapterCount: chapterDirs.length,
              imageCount: imageCount,
            )
          : ComicInfo(
              id: comicId,
              comicName: comicName,
              coverImage: coverImage,
              chapterCount: chapterDirs.length,
              imageCount: imageCount,
            );
      comicsToUpsert[comicInfo.id] = comicInfo;
    }

    if (chapterIdsToDelete.isNotEmpty) {
      await state.chapterInfoBox.deleteAll(chapterIdsToDelete);
    }
    if (chaptersToUpsert.isNotEmpty) {
      await state.chapterInfoBox.putAll(chaptersToUpsert);
    }
    if (comicsToUpsert.isNotEmpty) {
      await state.comicInfoBox.putAll(comicsToUpsert);
    }
  }
}
