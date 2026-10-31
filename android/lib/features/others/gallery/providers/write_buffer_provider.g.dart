// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'write_buffer_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$galleryWriteBufferHash() =>
    r'9d6cc077d39634a484885adae04d85e9b7edbb95';

/// 乐观写缓冲 Provider
///
/// 乐观状态仅在内存；服务端确认后才持久化缓存。
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
