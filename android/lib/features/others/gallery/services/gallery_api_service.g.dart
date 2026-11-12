// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gallery_api_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Gallery 服务端操作接口（服务端权威的唯一写入口）
///
/// 所有标签/标签关系/媒体标注的修改都通过这里写服务端, 本地表只做缓存.
/// 失败统一抛出 [ApiException]（含可读 message）.

@ProviderFor(galleryApi)
final galleryApiProvider = GalleryApiProvider._();

/// Gallery 服务端操作接口（服务端权威的唯一写入口）
///
/// 所有标签/标签关系/媒体标注的修改都通过这里写服务端, 本地表只做缓存.
/// 失败统一抛出 [ApiException]（含可读 message）.

final class GalleryApiProvider
    extends
        $FunctionalProvider<
          GalleryApiService,
          GalleryApiService,
          GalleryApiService
        >
    with $Provider<GalleryApiService> {
  /// Gallery 服务端操作接口（服务端权威的唯一写入口）
  ///
  /// 所有标签/标签关系/媒体标注的修改都通过这里写服务端, 本地表只做缓存.
  /// 失败统一抛出 [ApiException]（含可读 message）.
  GalleryApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'galleryApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$galleryApiHash();

  @$internal
  @override
  $ProviderElement<GalleryApiService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  GalleryApiService create(Ref ref) {
    return galleryApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GalleryApiService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GalleryApiService>(value),
    );
  }
}

String _$galleryApiHash() => r'fa886bd04cbdaa793a059b507f70af2933d1ee64';
