// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stats_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$galleryDbStatsHash() => r'215232d04d9fc65f5e1959946787a9ac1ad168f5';

/// 数据库统计信息 Provider
///
/// Copied from [galleryDbStats].
@ProviderFor(galleryDbStats)
final galleryDbStatsProvider = FutureProvider<GalleryDbStats>.internal(
  galleryDbStats,
  name: r'galleryDbStatsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$galleryDbStatsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef GalleryDbStatsRef = FutureProviderRef<GalleryDbStats>;
String _$galleryCachedStorageStatsHash() =>
    r'86fda8df347d6d88695f56155293830b6c0dc009';

/// 文件存储统计信息 (持久化缓存, 仅在手动刷新或数据同步后更新)
///
/// Copied from [GalleryCachedStorageStats].
@ProviderFor(GalleryCachedStorageStats)
final galleryCachedStorageStatsProvider =
    NotifierProvider<GalleryCachedStorageStats, GalleryStorageStats>.internal(
  GalleryCachedStorageStats.new,
  name: r'galleryCachedStorageStatsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$galleryCachedStorageStatsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$GalleryCachedStorageStats = Notifier<GalleryStorageStats>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
