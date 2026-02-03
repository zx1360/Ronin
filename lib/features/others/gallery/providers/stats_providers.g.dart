// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stats_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$galleryDbStatsHash() => r'02d3a4230db6c03f1571fd6c3f74a939a03b4ec0';

/// 数据库统计信息 Provider
///
/// Copied from [galleryDbStats].
@ProviderFor(galleryDbStats)
final galleryDbStatsProvider =
    AutoDisposeFutureProvider<GalleryDbStats>.internal(
  galleryDbStats,
  name: r'galleryDbStatsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$galleryDbStatsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef GalleryDbStatsRef = AutoDisposeFutureProviderRef<GalleryDbStats>;
String _$galleryStorageStatsHash() =>
    r'84e0d1dadefd54749f870947f0bd26a7e7eac7c4';

/// 文件存储统计信息 Provider
///
/// Copied from [galleryStorageStats].
@ProviderFor(galleryStorageStats)
final galleryStorageStatsProvider =
    AutoDisposeFutureProvider<GalleryStorageStats>.internal(
  galleryStorageStats,
  name: r'galleryStorageStatsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$galleryStorageStatsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef GalleryStorageStatsRef
    = AutoDisposeFutureProviderRef<GalleryStorageStats>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
