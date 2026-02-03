// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tag_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$tagTreeHash() => r'03c77fa2c03d0b4b70e502f7461605318df44b9e';

/// 标签树 Provider
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
String _$currentMediaTagsHash() => r'ce3e37d342008ffe94967ade77de45e2a2983b98';

/// 当前媒体文件的标签 Provider
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
