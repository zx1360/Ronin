// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_data_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$galleryLocalDataControllerHash() =>
    r'320173512d22608199e5c721b456eb717e2973e1';

/// 本地缓存的清空动作。
///
/// 只清本机（gallery.db 与下载的文件），**不触碰服务端**；清空后把游标复位、让派生数据重取。
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
