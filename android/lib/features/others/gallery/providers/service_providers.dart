import 'package:flutter_riverpod/legacy.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/core/services/storage/app_database.dart';
import 'package:torrid/features/others/gallery/services/gallery_database_service.dart';
import 'package:torrid/features/others/gallery/services/gallery_storage_service.dart';

part 'service_providers.g.dart';

// 基础服务 Providers

/// 数据库服务 Provider
@Riverpod(keepAlive: true)
GalleryDatabaseService galleryDatabase(Ref ref) {
  return GalleryDatabaseService(ref.watch(appDatabaseProvider));
}

/// 文件存储服务 Provider
@Riverpod(keepAlive: true)
GalleryStorageService galleryStorage(Ref ref) {
  return GalleryStorageService(ref.watch(galleryDatabaseProvider).libraryId);
}

final galleryFilesRevisionProvider = StateProvider<int>((ref) => 0);
