// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gallery_sync_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$galleryUploadStatsHash() =>
    r'2ecd7fee1730c12d79f32848c163c6893dac0801';

/// 待上传数据统计 Provider
/// 按照 modified_count 计算需要上传的记录：
/// - media_assets: sync_count <= modified_count 的记录
/// - tags: 全量
/// - media_tag_links: 与涉及到的 media_assets 关联的记录
///
/// Copied from [galleryUploadStats].
@ProviderFor(galleryUploadStats)
final galleryUploadStatsProvider =
    AutoDisposeFutureProvider<UploadStats>.internal(
  galleryUploadStats,
  name: r'galleryUploadStatsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$galleryUploadStatsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef GalleryUploadStatsRef = AutoDisposeFutureProviderRef<UploadStats>;
String _$gallerySyncServiceHash() =>
    r'da026b7fa1403c51406540c33643989c9009974f';

/// Gallery 同步服务 Provider
///
/// Copied from [GallerySyncService].
@ProviderFor(GallerySyncService)
final gallerySyncServiceProvider =
    AutoDisposeNotifierProvider<GallerySyncService, SyncProgress>.internal(
  GallerySyncService.new,
  name: r'gallerySyncServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$gallerySyncServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$GallerySyncService = AutoDisposeNotifier<SyncProgress>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
