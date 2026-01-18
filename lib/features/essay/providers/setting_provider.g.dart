// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'setting_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$browseManagerHash() => r'813331531e532857c0721b5d7b3223a732f74964';

/// 浏览设置管理器
///
/// 管理随笔浏览页面的排序和筛选设置。
///
/// Copied from [BrowseManager].
@ProviderFor(BrowseManager)
final browseManagerProvider =
    AutoDisposeNotifierProvider<BrowseManager, BrowseSettings>.internal(
  BrowseManager.new,
  name: r'browseManagerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$browseManagerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$BrowseManager = AutoDisposeNotifier<BrowseSettings>;
String _$contentServerHash() => r'fdd5b1e710b49201d78772f119e8209067d1e379';

/// 当前选中/正在查看的随笔
///
/// 用于详情页和相关操作时保持当前随笔的引用。
///
/// **重命名说明**: 原名 `ContentServer`，为提高可读性重命名为 `SelectedEssay`。
/// 生成的 provider 名称保持 `contentServerProvider` 以保持向后兼容。
///
/// Copied from [ContentServer].
@ProviderFor(ContentServer)
final contentServerProvider =
    AutoDisposeNotifierProvider<ContentServer, Essay?>.internal(
  ContentServer.new,
  name: r'contentServerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$contentServerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ContentServer = AutoDisposeNotifier<Essay?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
