import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/others/gallery/models/gallery_overview.dart';
import 'package:torrid/features/others/gallery/providers/service_providers.dart';
import 'package:torrid/features/others/gallery/services/gallery_storage_service.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

part 'stats_providers.g.dart';

@riverpod
Stream<({int media, int tags, int links})> galleryDbStats(Ref ref) =>
    ref.watch(galleryDatabaseProvider).watchCounts();

@riverpod
Future<GalleryStorageStats> galleryStorageStats(Ref ref) {
  ref.watch(galleryFilesRevisionProvider);
  return ref.watch(galleryStorageProvider).getStorageStats();
}

/// 服务端画廊总览 Provider
@riverpod
Future<GalleryOverview> galleryServerOverview(Ref ref) async {
  final apiClient = ref.watch(apiClientManagerProvider);
  final response = await apiClient.get('/API/gallery/overview');
  return GalleryOverview.fromJson(response.data as Map<String, dynamic>);
}

/// 有关联标签的媒体 ID 集合 Provider（用于浏览页标签指示器）
@Riverpod(keepAlive: true)
Stream<Set<String>> mediaIdsWithTags(Ref ref) =>
    ref.watch(galleryDatabaseProvider).watchMediaIdsWithTags();
