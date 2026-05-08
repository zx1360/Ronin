// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notifier_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$comicServiceHash() => r'1a397c8846593dbdfbe6e8b5ad07ebed91e67d4e';

/// Comic 模块的核心服务
///
/// 提供以下功能：
/// - 阅读偏好管理
/// - 漫画下载与保存
/// - 元数据刷新
///
/// Copied from [ComicService].
@ProviderFor(ComicService)
final comicServiceProvider =
    AutoDisposeNotifierProvider<ComicService, ComicRepository>.internal(
  ComicService.new,
  name: r'comicServiceProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$comicServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ComicService = AutoDisposeNotifier<ComicRepository>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
