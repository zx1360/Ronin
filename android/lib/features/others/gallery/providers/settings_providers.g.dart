// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(GalleryBrowseSettings)
final galleryBrowseSettingsProvider = GalleryBrowseSettingsProvider._();

final class GalleryBrowseSettingsProvider
    extends $NotifierProvider<GalleryBrowseSettings, GalleryBrowseOptions> {
  GalleryBrowseSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'galleryBrowseSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$galleryBrowseSettingsHash();

  @$internal
  @override
  GalleryBrowseSettings create() => GalleryBrowseSettings();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GalleryBrowseOptions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GalleryBrowseOptions>(value),
    );
  }
}

String _$galleryBrowseSettingsHash() =>
    r'c4a7b903ed108f6c54f18526b34644c78a6423ad';

abstract class _$GalleryBrowseSettings extends $Notifier<GalleryBrowseOptions> {
  GalleryBrowseOptions build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<GalleryBrowseOptions, GalleryBrowseOptions>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<GalleryBrowseOptions, GalleryBrowseOptions>,
              GalleryBrowseOptions,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(GalleryDownloadFilters)
final galleryDownloadFiltersProvider = GalleryDownloadFiltersProvider._();

final class GalleryDownloadFiltersProvider
    extends $NotifierProvider<GalleryDownloadFilters, GalleryDownloadOptions> {
  GalleryDownloadFiltersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'galleryDownloadFiltersProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$galleryDownloadFiltersHash();

  @$internal
  @override
  GalleryDownloadFilters create() => GalleryDownloadFilters();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GalleryDownloadOptions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GalleryDownloadOptions>(value),
    );
  }
}

String _$galleryDownloadFiltersHash() =>
    r'13e070ea3b0fd532275b6ab98ab2fb49890a82dd';

abstract class _$GalleryDownloadFilters
    extends $Notifier<GalleryDownloadOptions> {
  GalleryDownloadOptions build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<GalleryDownloadOptions, GalleryDownloadOptions>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<GalleryDownloadOptions, GalleryDownloadOptions>,
              GalleryDownloadOptions,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
