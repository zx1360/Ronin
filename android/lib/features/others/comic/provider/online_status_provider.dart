/// Comic 模块的在线数据提供者
///
/// 从服务器获取漫画和章节信息。
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/core/services/network/api_client.dart';
import 'package:torrid/features/others/comic/models/chapter_info.dart';
import 'package:torrid/features/others/comic/models/comic_info.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

part 'online_status_provider.g.dart';

/// 获取所有在线漫画信息（不过滤，由 UI 层控制可见性）
@riverpod
Future<List<ComicInfo>> comicsOnline(ComicsOnlineRef ref) async {
  return _fetchList(
    ref.watch(apiClientManagerProvider),
    '/API/comic/comic-info',
    ComicInfo.fromJson,
  );
}

/// 根据漫画 ID 获取对应的章节信息
@riverpod
Future<List<ChapterInfo>> onlineChaptersWithComicId(
  OnlineChaptersWithComicIdRef ref, {
  required String comicId,
}) async {
  return _fetchList(
    ref.watch(apiClientManagerProvider),
    '/API/comic/comic-info/$comicId',
    ChapterInfo.fromJson,
  );
}

/// 根据章节 ID 获取对应的图片信息
@riverpod
Future<List<Map<String, dynamic>>> onlineImagesWithChapterId(
  OnlineImagesWithChapterIdRef ref, {
  required String chapterId,
}) async {
  return _fetchList(
    ref.watch(apiClientManagerProvider),
    '/API/comic/chapter-info/$chapterId',
    (row) => row,
  );
}

Future<List<T>> _fetchList<T>(
  ApiClient client,
  String path,
  T Function(Map<String, dynamic>) parse,
) async {
  try {
    final response = await client.get(path);
    final data = response.data;
    if (data == null) return [];
    if (data is! List) throw const FormatException('服务端返回了无效的漫画列表');
    return data
        .map((row) => parse(Map<String, dynamic>.from(row as Map)))
        .toList();
  } catch (error) {
    throw ApiClient.mapError(error);
  }
}
