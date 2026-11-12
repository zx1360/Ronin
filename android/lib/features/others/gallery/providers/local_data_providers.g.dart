// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_data_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(GalleryLocalDataController)
final galleryLocalDataControllerProvider =
    GalleryLocalDataControllerProvider._();

final class GalleryLocalDataControllerProvider
    extends $NotifierProvider<GalleryLocalDataController, bool> {
  GalleryLocalDataControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'galleryLocalDataControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$galleryLocalDataControllerHash();

  @$internal
  @override
  GalleryLocalDataController create() => GalleryLocalDataController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$galleryLocalDataControllerHash() =>
    r'2e9caceb39d9a0e18c293f0bb8aa7dbd2a8a596b';

abstract class _$GalleryLocalDataController extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
