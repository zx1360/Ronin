// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tag_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$favoriteTagsHash() => r'f9b1921b24d700e0a047642e0f188a6163107606';

/// 快捷标签（收藏标签, 按路径排序）——浮层右栏 / 快捷选择使用
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
String _$tagTreeHash() => r'c8df66a1cfb7c6e4635cbd62a0ca47ca610c57cc';

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
String _$currentMediaTagsHash() => r'689048dd7b1b77ea957e0b07dcedf13d808cb295';

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
