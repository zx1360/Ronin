import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/others/gallery/services/gallery_database_service.dart';
import 'package:torrid/features/others/gallery/services/gallery_storage_service.dart';

part 'service_providers.g.dart';

// ============ 基础服务 Providers ============

/// 数据库服务 Provider
@Riverpod(keepAlive: true)
GalleryDatabaseService galleryDatabase(GalleryDatabaseRef ref) {
  return GalleryDatabaseService();
}

/// 文件存储服务 Provider
@Riverpod(keepAlive: true)
GalleryStorageService galleryStorage(GalleryStorageRef ref) {
  return GalleryStorageService();
}
