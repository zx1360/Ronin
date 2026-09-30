// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'maintenance_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$galleryMaintenanceHash() =>
    r'47c2a4e4dc98df716e55e37b86ee63b97473f95f';

/// 设置页的维护操作: 下载 / 标记已处理 / 清空数据
///
/// 页面只负责确认对话框与提示, 数据与文件的实际改动都在这里完成。
///
/// Copied from [GalleryMaintenance].
@ProviderFor(GalleryMaintenance)
final galleryMaintenanceProvider = AutoDisposeNotifierProvider<
    GalleryMaintenance, GalleryMaintenanceState>.internal(
  GalleryMaintenance.new,
  name: r'galleryMaintenanceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$galleryMaintenanceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$GalleryMaintenance = AutoDisposeNotifier<GalleryMaintenanceState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
