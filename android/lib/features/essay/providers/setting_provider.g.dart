// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'setting_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$browseManagerHash() => r'2bf7e6a3723c841bd2874e9a565dfb3a5cbb0293';

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
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
