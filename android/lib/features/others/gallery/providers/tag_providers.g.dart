// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tag_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$favoriteTagsHash() => r'747a59d96e0aacc3ccfcb987f027011146b0fef2';

/// 快捷标签（收藏标签，按绑定媒体数降序）
///
/// Copied from [favoriteTags].
@ProviderFor(favoriteTags)
final favoriteTagsProvider = AutoDisposeProvider<List<Tag>>.internal(
  favoriteTags,
  name: r'favoriteTagsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$favoriteTagsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef FavoriteTagsRef = AutoDisposeProviderRef<List<Tag>>;
String _$tagTreeHash() => r'83659a5badc142d89dcebdf49285ff81927b0751';

/// 标签树 Provider
///
/// Gallery 使用离线工作副本；在线相册写入前先确认待回传操作。
///
/// Copied from [TagTree].
@ProviderFor(TagTree)
final tagTreeProvider =
    AutoDisposeAsyncNotifierProvider<TagTree, List<Tag>>.internal(
  TagTree.new,
  name: r'tagTreeProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$tagTreeHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$TagTree = AutoDisposeAsyncNotifier<List<Tag>>;
String _$currentMediaTagsHash() => r'8571ad4f260c61b4691c770d549092efd1b0b8d8';

/// 当前媒体文件的标签 Provider（读本地缓存）
///
/// Copied from [CurrentMediaTags].
@ProviderFor(CurrentMediaTags)
final currentMediaTagsProvider =
    AutoDisposeAsyncNotifierProvider<CurrentMediaTags, List<Tag>>.internal(
  CurrentMediaTags.new,
  name: r'currentMediaTagsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$currentMediaTagsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$CurrentMediaTags = AutoDisposeAsyncNotifier<List<Tag>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
