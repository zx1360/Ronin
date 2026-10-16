// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notifier_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$comicServiceHash() => r'e673a5fbda36581fe50cab026cf066360086721c';

/// 阅读偏好与元数据服务。
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
