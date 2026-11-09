/// Comic 模块的核心业务逻辑服务
///
/// 管理阅读偏好、本地元数据与服务端同步。
library;

import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/others/comic/models/chapter_info.dart';
import 'package:torrid/features/others/comic/models/comic_info.dart';
import 'package:torrid/features/others/comic/models/comic_preference.dart';
import 'package:torrid/features/others/comic/provider/box_provider.dart';
import 'package:torrid/features/others/comic/provider/download_task_provider.dart';
import 'package:torrid/features/others/comic/provider/online_status_provider.dart';
import 'package:torrid/features/others/comic/provider/service_provider.dart';
import 'package:torrid/features/others/comic/provider/status_provider.dart';

part 'notifier_provider.g.dart';

/// 与服务端同步的结果。
class ComicSyncResult {
  /// 本地没有任何已下载的漫画时为 false；此时不该提示"已同步 0 本"。
  final bool hasLocalComics;

  /// 服务端仍有、已同步字段的本数。
  final int synced;

  /// 服务端章节数比本地多、已加入下载队列的本数。
  final int updated;

  const ComicSyncResult({
    required this.hasLocalComics,
    this.synced = 0,
    this.updated = 0,
  });

  String get message => updated > 0
      ? '已同步 $synced 本漫画，$updated 本有更新，已加入下载队列'
      : '已同步 $synced 本漫画，均为最新';
}

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

/// 阅读偏好与元数据服务。
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

  /// 用服务端数据同步本地漫画：刷新各字段，并把有新章节的漫画加入下载队列。
  Future<ComicSyncResult> syncWithServer() async {
    final localComics = ref.read(comicInfosProvider);
    if (localComics.isEmpty) {
      return const ComicSyncResult(hasLocalComics: false);
    }

    // 强制重取服务端列表，否则拿到的可能是上次的缓存
    ref.invalidate(comicsOnlineProvider);
    final serverComics = await ref.read(comicsOnlineProvider.future);
    final serverById = {for (final comic in serverComics) comic.id: comic};

    var synced = 0;
    var updated = 0;
    for (final local in localComics) {
      final server = serverById[local.id];
      if (server == null) continue; // 服务端已没有这本，本地保持原样

      await syncFieldsFromServer(server);
      synced++;

      if (server.chapterCount > local.chapterCount) {
        await ref
            .read(comicDownloadTasksProvider.notifier)
            .enqueueComic(comicInfo: local);
        updated++;
      }
    }
    return ComicSyncResult(
      hasLocalComics: true,
      synced: synced,
      updated: updated,
    );
  }

  /// 刷新所有漫画元数据（完全重建）
  Future<void> refreshInfosAll() async {
    ref.invalidate(allInfosProvider);
    final infos = await ref.read(allInfosProvider.future);
    final comics = infos['comicInfos'] as Map<String, ComicInfo>;
    final chapters = infos['chapterInfos'] as Map<String, ChapterInfo>;
    final missing = state.comicInfoBox.keys
        .where((id) => !comics.containsKey(id))
        .toList();
    await state.prefBox.deleteAll(missing);
    await state.comicInfoBox.deleteAll(missing);
    await state.chapterInfoBox.deleteAll(
      state.chapterInfoBox.keys
          .where((id) => !chapters.containsKey(id))
          .toList(),
    );

    await state.comicInfoBox.putAll(comics);
    await state.chapterInfoBox.putAll(chapters);
  }

  Future<void> refreshChanged() => refreshInfosAll();
}
