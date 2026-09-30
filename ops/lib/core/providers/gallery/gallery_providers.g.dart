// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gallery_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$galleryApiClientHash() => r'9763b5df54cabbb2b5c13499d451ae282b73b58c';

/// 画廊 API 客户端单例。
///
/// Copied from [galleryApiClient].
@ProviderFor(galleryApiClient)
final galleryApiClientProvider = Provider<GalleryApiClient>.internal(
  galleryApiClient,
  name: r'galleryApiClientProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$galleryApiClientHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef GalleryApiClientRef = ProviderRef<GalleryApiClient>;
String _$galleryMediaRootHash() => r'1d9f7c7569043f89ec374d7ca9b5ef07e9ec7a30';

/// 服务端 gallery/Media 的绝对路径（用于「打开所在目录」）。
///
/// 取值来自 `/API/ops/overview`；尚未取到时由调用方提示重试，
/// 绝不猜测路径（猜错会打开错误的目录）。
///
/// Copied from [galleryMediaRoot].
@ProviderFor(galleryMediaRoot)
final galleryMediaRootProvider = Provider<String?>.internal(
  galleryMediaRoot,
  name: r'galleryMediaRootProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$galleryMediaRootHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef GalleryMediaRootRef = ProviderRef<String?>;
String _$ignoredDuplicatesHash() => r'aa31fc553133f2c517f256201621af551a38b75b';

/// 被标记为「非重复」的媒体（可恢复）。
///
/// Copied from [ignoredDuplicates].
@ProviderFor(ignoredDuplicates)
final ignoredDuplicatesProvider = FutureProvider<List<GalleryMedia>>.internal(
  ignoredDuplicates,
  name: r'ignoredDuplicatesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$ignoredDuplicatesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef IgnoredDuplicatesRef = FutureProviderRef<List<GalleryMedia>>;
String _$duplicateGroupsHash() => r'bd48ac2cc51a526fd676374f6806d4d5e100c425';

/// See also [duplicateGroups].
@ProviderFor(duplicateGroups)
final duplicateGroupsProvider = FutureProvider<DuplicatesResult>.internal(
  duplicateGroups,
  name: r'duplicateGroupsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$duplicateGroupsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef DuplicateGroupsRef = FutureProviderRef<DuplicatesResult>;
String _$deletedMediaControllerHash() =>
    r'806948cf2f9bde4216a8ede78991fa88a8eaae75';

/// 软删除媒体列表控制器：按需加载 + 多选 + 取消软删除。
///
/// Copied from [DeletedMediaController].
@ProviderFor(DeletedMediaController)
final deletedMediaControllerProvider =
    NotifierProvider<DeletedMediaController, DeletedMediaState>.internal(
  DeletedMediaController.new,
  name: r'deletedMediaControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$deletedMediaControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$DeletedMediaController = Notifier<DeletedMediaState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
