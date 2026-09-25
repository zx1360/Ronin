// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'write_buffer_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$galleryWriteBufferHash() =>
    r'16eb922b7bab5a37d2a502778ce696df0b6b1318';

/// 乐观写缓冲 Provider
///
/// 把"服务端推送"与"失败回滚"接到具体 provider: 本地先改, 后台合并推送,
/// 重试仍失败则回滚本地缓存与内存状态, 保证本地始终向服务端看齐.
///
/// Copied from [galleryWriteBuffer].
@ProviderFor(galleryWriteBuffer)
final galleryWriteBufferProvider = Provider<GalleryWriteBuffer>.internal(
  galleryWriteBuffer,
  name: r'galleryWriteBufferProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$galleryWriteBufferHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef GalleryWriteBufferRef = ProviderRef<GalleryWriteBuffer>;
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
