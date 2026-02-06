// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$galleryModifiedCountHash() =>
    r'd0c0b8767e9086366e97a72fe955b8e8f5999a7d';

/// modified_count - 记录最后一次操作的媒体文件在队列中的位置
///
/// Copied from [GalleryModifiedCount].
@ProviderFor(GalleryModifiedCount)
final galleryModifiedCountProvider =
    NotifierProvider<GalleryModifiedCount, int>.internal(
  GalleryModifiedCount.new,
  name: r'galleryModifiedCountProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$galleryModifiedCountHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$GalleryModifiedCount = Notifier<int>;
String _$galleryCurrentIndexHash() =>
    r'0d07dd3f91fb9e2a53eaa051895cdc2145576cc4';

/// 当前浏览位置索引
///
/// Copied from [GalleryCurrentIndex].
@ProviderFor(GalleryCurrentIndex)
final galleryCurrentIndexProvider =
    NotifierProvider<GalleryCurrentIndex, int>.internal(
  GalleryCurrentIndex.new,
  name: r'galleryCurrentIndexProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$galleryCurrentIndexHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$GalleryCurrentIndex = Notifier<int>;
String _$galleryGridColumnsHash() =>
    r'7911eebfac5c3da40dab130ee2042944283b58b4';

/// 网格视图每行数量 (3, 4, 8, 16)
///
/// Copied from [GalleryGridColumns].
@ProviderFor(GalleryGridColumns)
final galleryGridColumnsProvider =
    NotifierProvider<GalleryGridColumns, int>.internal(
  GalleryGridColumns.new,
  name: r'galleryGridColumnsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$galleryGridColumnsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$GalleryGridColumns = Notifier<int>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
