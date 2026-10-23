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
String _$tagTreeHash() => r'da14089aef1b68862f075ca42af58b5d9b9a5971';

/// 标签树 Provider
///
/// 读取本地缓存（离线可浏览）; 所有写操作先落服务端, 再把服务端结果写入缓存。
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
String _$currentMediaTagsHash() => r'5a06d59d64a1cab01c5c0575b6306a7ba8f4ec50';

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
