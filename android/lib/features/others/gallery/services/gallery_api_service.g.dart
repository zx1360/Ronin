// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gallery_api_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$galleryApiHash() => r'c9c3c11cd4716b79ed2f10d1376c2a91f3849a4d';

/// Gallery 服务端操作接口（服务端权威的唯一写入口）
///
/// 所有标签/标签关系/媒体标注的修改都通过这里写服务端, 本地表只做缓存.
/// 失败统一抛出 [ApiException]（含可读 message）.
///
/// Copied from [galleryApi].
@ProviderFor(galleryApi)
final galleryApiProvider = Provider<GalleryApiService>.internal(
  galleryApi,
  name: r'galleryApiProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$galleryApiHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef GalleryApiRef = ProviderRef<GalleryApiService>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
