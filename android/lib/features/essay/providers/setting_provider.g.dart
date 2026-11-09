// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'setting_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$browseManagerHash() => r'2c201471d7c6feaaed6c8a1c83919b9a8ced9fa2';

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
