// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gallery_sync_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$galleryProcessedStatsHash() =>
    r'9c67572542a9ce8a855217ed0d012c52ce885eec';

/// 与「标记已处理」使用相同范围的主文件统计。
///
/// Copied from [galleryProcessedStats].
@ProviderFor(galleryProcessedStats)
final galleryProcessedStatsProvider =
    AutoDisposeFutureProvider<({int mediaCount, int deletedCount})>.internal(
  galleryProcessedStats,
  name: r'galleryProcessedStatsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$galleryProcessedStatsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef GalleryProcessedStatsRef
    = AutoDisposeFutureProviderRef<({int mediaCount, int deletedCount})>;
String _$gallerySyncServiceHash() =>
    r'2fab52de2ec34271c0bb2215da84cf26858cdc92';

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
