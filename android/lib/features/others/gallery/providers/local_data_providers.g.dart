// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_data_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$galleryLocalDataControllerHash() =>
    r'0f6448bb1d606be722b3e6732d93c5dc15cc8141';

/// 本地缓存的清空动作。
///
/// 只清本机（gallery.db 与下载的文件），**不触碰服务端**；清空后把游标复位、让派生数据重取。
/// 此前设置页把"复位 + 失效一堆 provider"抄了三遍（还各漏了几项），这里收敛成一条路径。
///
/// Copied from [GalleryLocalDataController].
@ProviderFor(GalleryLocalDataController)
final galleryLocalDataControllerProvider =
    NotifierProvider<GalleryLocalDataController, bool>.internal(
  GalleryLocalDataController.new,
  name: r'galleryLocalDataControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$galleryLocalDataControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$GalleryLocalDataController = Notifier<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
