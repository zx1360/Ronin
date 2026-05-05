/// Comic 模块的在线数据提供者
///
/// 从服务器获取漫画和章节信息。
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/others/comic/models/chapter_info.dart';
import 'package:torrid/features/others/comic/models/comic_info.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

part 'online_status_provider.g.dart';

// ============================================================================
// 在线漫画数据
// ============================================================================

/// 获取所有在线漫画信息（安卓端仅展示 is_public=true 的漫画）
@riverpod
Future<List<ComicInfo>> comicsOnline(ComicsOnlineRef ref) async {
  final response = await ref.read(
    fetcherProvider(path: "/API/comic/comic-info").future,
  );
  if (response == null) {
    throw Exception("获取在线漫画列表失败");
  }

  final allComics = (response.data as List)
      .map((row) => ComicInfo.fromJson(row as Map<String, dynamic>))
      .toList();

  // 安卓端隐藏 isPublic=false 的漫画
  return allComics.where((c) => c.isPublic??true).toList();
}

/// 根据漫画 ID 获取对应的章节信息
@riverpod
Future<List<ChapterInfo>> onlineChaptersWithComicId(
  OnlineChaptersWithComicIdRef ref, {
  required String comicId,
}) async {
  final response = await ref.read(
    fetcherProvider(path: "/API/comic/comic-info/$comicId").future,
  );
  if (response == null) {
    return [];
  }

  return (response.data as List)
      .map((row) => ChapterInfo.fromJson(row as Map<String, dynamic>))
      .toList();
}

/// 根据章节 ID 获取对应的图片信息
@riverpod
Future<List<Map<String, dynamic>>> onlineImagesWithChapterId(
  OnlineImagesWithChapterIdRef ref, {
  required String chapterId,
}) async {
  final response = await ref.read(
    fetcherProvider(path: "/API/comic/chapter-info/$chapterId").future,
  );
  if (response == null) {
    return [];
  }

  return (response.data as List)
      .map((row) => row as Map<String, dynamic>)
      .toList();
}

// ============================================================================
// 同步操作
// ============================================================================

/// 同步已读状态：将本地已读漫画的 ID 发送给服务器，并获取各漫画的章节总数
@riverpod
class ComicSyncController extends _$ComicSyncController {
  @override
  AsyncValue<Map<String, int>?> build() {
    return const AsyncValue.data(null);
  }

  /// 标记单本漫画为已读
  Future<void> markAsReaded(String comicId) async {
    final apiClient = ref.read(apiClientManagerProvider);
    try {
      await apiClient.putJson(
        '/API/comic/comic-info/$comicId',
        data: {'readed': true},
      );
      // 刷新在线漫画列表
      ref.invalidate(comicsOnlineProvider);
    } catch (e) {
      throw Exception('标记已读失败: $e');
    }
  }

  /// 同步已读状态：发送本地已读漫画ID列表，获取服务器章节总数
  /// 返回 {comicId: serverChapterCount}，客户端自行对比本地章节数决定是否增量下载
  Future<Map<String, int>> syncReadedStatus(List<String> readedIds) async {
    state = const AsyncValue.loading();

    try {
      final apiClient = ref.read(apiClientManagerProvider);
      final response = await apiClient.postJson(
        '/API/comic/sync-readed',
        data: {'readed_ids': readedIds},
      );

      final data = response.data as Map<String, dynamic>;
      final newChaptersRaw = data['new_chapters'] as Map<String, dynamic>? ?? {};

      final result = <String, int>{};
      newChaptersRaw.forEach((key, value) {
        result[key] = (value as num).toInt();
      });

      state = AsyncValue.data(result);
      return result;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }
}
