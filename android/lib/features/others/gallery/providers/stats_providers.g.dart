// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stats_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(galleryDbStats)
final galleryDbStatsProvider = GalleryDbStatsProvider._();

final class GalleryDbStatsProvider
    extends
        $FunctionalProvider<
          AsyncValue<GalleryDbStats>,
          GalleryDbStats,
          Stream<GalleryDbStats>
        >
    with $FutureModifier<GalleryDbStats>, $StreamProvider<GalleryDbStats> {
  GalleryDbStatsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'galleryDbStatsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$galleryDbStatsHash();

  @$internal
  @override
  $StreamProviderElement<GalleryDbStats> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<GalleryDbStats> create(Ref ref) {
    return galleryDbStats(ref);
  }
}

String _$galleryDbStatsHash() => r'6ce866b15395b8687b7365ebede61ccaa3956dd3';

@ProviderFor(GalleryCachedStorageStats)
final galleryCachedStorageStatsProvider = GalleryCachedStorageStatsProvider._();

final class GalleryCachedStorageStatsProvider
    extends
        $AsyncNotifierProvider<GalleryCachedStorageStats, GalleryStorageStats> {
  GalleryCachedStorageStatsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'galleryCachedStorageStatsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$galleryCachedStorageStatsHash();

  @$internal
  @override
  GalleryCachedStorageStats create() => GalleryCachedStorageStats();
}

String _$galleryCachedStorageStatsHash() =>
    r'f0893fe9e4c4ace489551ec27566396b7b8ee116';

abstract class _$GalleryCachedStorageStats
    extends $AsyncNotifier<GalleryStorageStats> {
  FutureOr<GalleryStorageStats> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<GalleryStorageStats>, GalleryStorageStats>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<GalleryStorageStats>, GalleryStorageStats>,
              AsyncValue<GalleryStorageStats>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// 服务端画廊总览 Provider

@ProviderFor(galleryServerOverview)
final galleryServerOverviewProvider = GalleryServerOverviewProvider._();

/// 服务端画廊总览 Provider

final class GalleryServerOverviewProvider
    extends
        $FunctionalProvider<
          AsyncValue<GalleryOverview>,
          GalleryOverview,
          FutureOr<GalleryOverview>
        >
    with $FutureModifier<GalleryOverview>, $FutureProvider<GalleryOverview> {
  /// 服务端画廊总览 Provider
  GalleryServerOverviewProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'galleryServerOverviewProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$galleryServerOverviewHash();

  @$internal
  @override
  $FutureProviderElement<GalleryOverview> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<GalleryOverview> create(Ref ref) {
    return galleryServerOverview(ref);
  }
}

String _$galleryServerOverviewHash() =>
    r'ac1868c6446cee7678b4933a8fb64305bcaa3251';

/// 有关联标签的媒体 ID 集合 Provider（用于浏览页标签指示器）

@ProviderFor(mediaIdsWithTags)
final mediaIdsWithTagsProvider = MediaIdsWithTagsProvider._();

/// 有关联标签的媒体 ID 集合 Provider（用于浏览页标签指示器）

final class MediaIdsWithTagsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Set<String>>,
          Set<String>,
          Stream<Set<String>>
        >
    with $FutureModifier<Set<String>>, $StreamProvider<Set<String>> {
  /// 有关联标签的媒体 ID 集合 Provider（用于浏览页标签指示器）
  MediaIdsWithTagsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mediaIdsWithTagsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mediaIdsWithTagsHash();

  @$internal
  @override
  $StreamProviderElement<Set<String>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Set<String>> create(Ref ref) {
    return mediaIdsWithTags(ref);
  }
}

String _$mediaIdsWithTagsHash() => r'efc2547cfd92f9ccd7814fc459339ac8c75c4173';
