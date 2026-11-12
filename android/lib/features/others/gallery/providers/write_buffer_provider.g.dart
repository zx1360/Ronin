// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'write_buffer_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(galleryWriteBuffer)
final galleryWriteBufferProvider = GalleryWriteBufferProvider._();

final class GalleryWriteBufferProvider
    extends
        $FunctionalProvider<
          GalleryWriteBuffer,
          GalleryWriteBuffer,
          GalleryWriteBuffer
        >
    with $Provider<GalleryWriteBuffer> {
  GalleryWriteBufferProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'galleryWriteBufferProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$galleryWriteBufferHash();

  @$internal
  @override
  $ProviderElement<GalleryWriteBuffer> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  GalleryWriteBuffer create(Ref ref) {
    return galleryWriteBuffer(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GalleryWriteBuffer value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GalleryWriteBuffer>(value),
    );
  }
}

String _$galleryWriteBufferHash() =>
    r'c4c5ccc2cc55caeb094f0e9e70fb280d1e84ec4a';

@ProviderFor(GalleryWriteStatus)
final galleryWriteStatusProvider = GalleryWriteStatusProvider._();

final class GalleryWriteStatusProvider
    extends $NotifierProvider<GalleryWriteStatus, String?> {
  GalleryWriteStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'galleryWriteStatusProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$galleryWriteStatusHash();

  @$internal
  @override
  GalleryWriteStatus create() => GalleryWriteStatus();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$galleryWriteStatusHash() =>
    r'c64f476e51a919a9e92685967aef9a3154054ee6';

abstract class _$GalleryWriteStatus extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
