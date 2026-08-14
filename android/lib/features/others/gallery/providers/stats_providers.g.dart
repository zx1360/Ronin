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
String _$galleryServerOverviewHash() =>
    r'597191a2ecbfe52f23b750c2a523085336f28588';

/// 服务端画廊总览 Provider
///
/// Copied from [galleryServerOverview].
@ProviderFor(galleryServerOverview)
final galleryServerOverviewProvider = FutureProvider<GalleryOverview>.internal(
  galleryServerOverview,
  name: r'galleryServerOverviewProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$galleryServerOverviewHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef GalleryServerOverviewRef = FutureProviderRef<GalleryOverview>;
String _$mediaIdsWithTagsHash() => r'f778790de54d30bc2c7ace2fabc4f0b93ff4cac7';

/// 有关联标签的媒体 ID 集合 Provider（用于浏览页标签指示器）
///
/// Copied from [mediaIdsWithTags].
@ProviderFor(mediaIdsWithTags)
final mediaIdsWithTagsProvider = FutureProvider<Set<String>>.internal(
  mediaIdsWithTags,
  name: r'mediaIdsWithTagsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$mediaIdsWithTagsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef MediaIdsWithTagsRef = FutureProviderRef<Set<String>>;
String _$galleryCachedStorageStatsHash() =>
    r'd902e809ca67b11248f60f65ece41f7dd217a773';

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
