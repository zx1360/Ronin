// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gallery_sync_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Gallery 同步服务 Provider

@ProviderFor(GallerySyncService)
final gallerySyncServiceProvider = GallerySyncServiceProvider._();

/// Gallery 同步服务 Provider
final class GallerySyncServiceProvider
    extends $NotifierProvider<GallerySyncService, SyncProgress> {
  /// Gallery 同步服务 Provider
  GallerySyncServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'gallerySyncServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$gallerySyncServiceHash();

  @$internal
  @override
  GallerySyncService create() => GallerySyncService();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncProgress value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncProgress>(value),
    );
  }
}

String _$gallerySyncServiceHash() =>
    r'b307ce8bd8dfa2ac250978b8b46abb8d21bc03ce';

/// Gallery 同步服务 Provider

abstract class _$GallerySyncService extends $Notifier<SyncProgress> {
  SyncProgress build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SyncProgress, SyncProgress>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SyncProgress, SyncProgress>,
              SyncProgress,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(galleryProcessedStats)
final galleryProcessedStatsProvider = GalleryProcessedStatsProvider._();

final class GalleryProcessedStatsProvider
    extends
        $FunctionalProvider<
          AsyncValue<({int deletedCount, int mediaCount})>,
          ({int deletedCount, int mediaCount}),
          Stream<({int deletedCount, int mediaCount})>
        >
    with
        $FutureModifier<({int deletedCount, int mediaCount})>,
        $StreamProvider<({int deletedCount, int mediaCount})> {
  GalleryProcessedStatsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'galleryProcessedStatsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$galleryProcessedStatsHash();

  @$internal
  @override
  $StreamProviderElement<({int deletedCount, int mediaCount})> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<({int deletedCount, int mediaCount})> create(Ref ref) {
    return galleryProcessedStats(ref);
  }
}

String _$galleryProcessedStatsHash() =>
    r'09548f77341937fc13e8fbe12e215031d7f727d7';
