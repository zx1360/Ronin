/// Comic 模块的核心业务逻辑服务
///
/// 管理阅读偏好、本地元数据与服务端同步。
library;

import 'package:flutter_riverpod/misc.dart' show ProviderException;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/core/services/network/api_client.dart';
import 'package:torrid/features/others/comic/models/chapter_info.dart';
import 'package:torrid/features/others/comic/models/comic_info.dart';
import 'package:torrid/features/others/comic/services/comic_store.dart';
import 'package:torrid/features/others/comic/provider/download_task_provider.dart';
import 'package:torrid/features/others/comic/provider/online_status_provider.dart';
import 'package:path/path.dart' as p;
import 'package:torrid/features/others/comic/services/comic_storage.dart';
import 'package:torrid/providers/progress/progress.dart';
import 'package:torrid/providers/progress/progress_provider.dart';

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

@Riverpod(keepAlive: true)
class ComicService extends _$ComicService {
  @override
  ComicStore build() => ref.watch(comicStoreProvider);

  Future<void> modifyComicPref({
    required String comicId,
    int? chapterIndex,
    bool? isFlipMode,
  }) => state.updateProgress(
    comicId,
    chapterIndex: chapterIndex,
    flipReading: isFlipMode,
  );

  /// 用服务端数据同步本地漫画：刷新各字段，并把有新章节的漫画加入下载队列。
  Future<ComicSyncResult> syncWithServer() async {
    final localComics = await state.comics();
    if (localComics.isEmpty) {
      return const ComicSyncResult(hasLocalComics: false);
    }

    // 强制重取服务端列表，否则拿到的可能是上次的缓存
    final List<ComicInfo> serverComics;
    try {
      serverComics = await ref.refresh(comicsOnlineProvider.future);
    } on ProviderException catch (error) {
      throw ApiClient.mapError(error.exception);
    }
    final serverById = {for (final comic in serverComics) comic.id: comic};

    var synced = 0;
    var updated = 0;
    for (final local in localComics) {
      final server = serverById[local.id];
      if (server == null) continue; // 服务端已没有这本，本地保持原样

      await state.syncFields(server);
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
    final store = state;
    final (:comics, :chapters) = await _scanLocal();
    await store.replaceCatalog(
      comics.values.toList(),
      chapters.values.toList(),
    );
  }

  Future<({Map<String, ComicInfo> comics, Map<String, ChapterInfo> chapters})>
  _scanLocal() async {
    final directories = await localComicDirectories();
    final existing = await state.comics();
    final chapters = await state.chapters();
    final found = <String, ({ComicInfo comic, List<ChapterInfo> chapters})>{};
    final progress = ref.read(progressServiceProvider.notifier);
    progress.setProgress(
      Progress(
        current: 0,
        total: directories.length,
        currentMessage: '',
        message: '正在扫描漫画文件...',
      ),
    );
    try {
      for (var i = 0; i < directories.length; i++) {
        final directory = directories[i];
        final name = p.basename(directory.path);
        final downloaded = p.basename(directory.parent.path) == '.downloads';
        final matches = existing
            .where(
              (comic) =>
                  downloaded ? comic.id == name : comic.comicName == name,
            )
            .toList();
        for (final comic in matches.isEmpty ? <ComicInfo?>[null] : matches) {
          final data = await scanLocalComic(
            directory,
            existing: comic,
            existingChapters: chapters
                .where((chapter) => chapter.comicId == comic?.id)
                .toList(),
          );
          found[data.comic.id] = data;
        }
        progress.increaseProgress(current: i + 1, currentMessage: name);
      }
      return (
        comics: {for (final data in found.values) data.comic.id: data.comic},
        chapters: {
          for (final data in found.values)
            for (final chapter in data.chapters) chapter.id: chapter,
        },
      );
    } finally {
      progress.resetStatus();
    }
  }
}
