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
String _$galleryStorageStatsHash() =>
    r'4c545e89cb08af6a02968125bf78960501fea14f';

/// 文件存储统计信息 Provider (仅在手动刷新或操作后更新)
///
/// Copied from [galleryStorageStats].
@ProviderFor(galleryStorageStats)
final galleryStorageStatsProvider =
    FutureProvider<GalleryStorageStats>.internal(
  galleryStorageStats,
  name: r'galleryStorageStatsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$galleryStorageStatsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef GalleryStorageStatsRef = FutureProviderRef<GalleryStorageStats>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
