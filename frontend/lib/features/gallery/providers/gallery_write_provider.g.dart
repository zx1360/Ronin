// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gallery_write_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$galleryWriteServiceHash() =>
    r'c10d7b15a4289aa0716103d5707eac3c1b8881ce';

/// 服务端写入统一入口
///
/// 本地立即生效 → 推送（写缓冲合并 / 直推重试）→ 失败回滚, 全部收敛在
/// [GalleryWriteService]; 这里只把它接到具体 provider 与网络实现上。
///
/// Copied from [galleryWriteService].
@ProviderFor(galleryWriteService)
final galleryWriteServiceProvider = Provider<GalleryWriteService>.internal(
  galleryWriteService,
  name: r'galleryWriteServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$galleryWriteServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef GalleryWriteServiceRef = ProviderRef<GalleryWriteService>;
String _$galleryWriteStatusHash() =>
    r'c64f476e51a919a9e92685967aef9a3154054ee6';

/// 服务端写入的用户提示通道（由浮层/页面监听并弹出提示）
///
/// Copied from [GalleryWriteStatus].
@ProviderFor(GalleryWriteStatus)
final galleryWriteStatusProvider =
    NotifierProvider<GalleryWriteStatus, String?>.internal(
  GalleryWriteStatus.new,
  name: r'galleryWriteStatusProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$galleryWriteStatusHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$GalleryWriteStatus = Notifier<String?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
