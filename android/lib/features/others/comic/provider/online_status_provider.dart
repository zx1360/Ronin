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

/// 获取所有在线漫画信息（不过滤，由 UI 层控制可见性）
@riverpod
Future<List<ComicInfo>> comicsOnline(ComicsOnlineRef ref) async {
  final response = await ref.read(
    fetcherProvider(path: "/API/comic/comic-info").future,
  );
  if (response == null) {
    throw Exception("获取在线漫画列表失败");
  }

  return (response.data as List)
      .map((row) => ComicInfo.fromJson(row as Map<String, dynamic>))
      .toList();
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

/// 同步操作：检查更新并同步后端字段到本地
@riverpod
class ComicSyncController extends _$ComicSyncController {
  @override
  AsyncValue<Map<String, int>?> build() {
    return const AsyncValue.data(null);
  }

  /// 获取所有漫画的服务器章节总数
  /// 返回 {comicId: serverChapterCount}
  Future<Map<String, int>> fetchServerChapterCounts() async {
    state = const AsyncValue.loading();

    try {
      final apiClient = ref.read(apiClientManagerProvider);
      // 使用 sync-readed 端点获取章节计数（不传 readed_ids 则仅返回计数）
      final response = await apiClient.postJson(
        '/API/comic/sync-readed',
        data: {'readed_ids': <String>[]},
      );

      final data = response.data as Map<String, dynamic>;
      final newChaptersRaw =
          data['new_chapters'] as Map<String, dynamic>? ?? {};

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
