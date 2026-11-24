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
          AsyncValue<({int links, int media, int tags})>,
          ({int links, int media, int tags}),
          Stream<({int links, int media, int tags})>
        >
    with
        $FutureModifier<({int links, int media, int tags})>,
        $StreamProvider<({int links, int media, int tags})> {
  GalleryDbStatsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'galleryDbStatsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$galleryDbStatsHash();

  @$internal
  @override
  $StreamProviderElement<({int links, int media, int tags})> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<({int links, int media, int tags})> create(Ref ref) {
    return galleryDbStats(ref);
  }
}

String _$galleryDbStatsHash() => r'51159cc350e882ce721b35e75a5073b0e65023d0';

@ProviderFor(galleryStorageStats)
final galleryStorageStatsProvider = GalleryStorageStatsProvider._();

final class GalleryStorageStatsProvider
    extends
        $FunctionalProvider<
          AsyncValue<GalleryStorageStats>,
          GalleryStorageStats,
          FutureOr<GalleryStorageStats>
        >
    with
        $FutureModifier<GalleryStorageStats>,
        $FutureProvider<GalleryStorageStats> {
  GalleryStorageStatsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'galleryStorageStatsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$galleryStorageStatsHash();

  @$internal
  @override
  $FutureProviderElement<GalleryStorageStats> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<GalleryStorageStats> create(Ref ref) {
    return galleryStorageStats(ref);
  }
}

String _$galleryStorageStatsHash() =>
    r'ab457ca03fc4c83aded02f84b7e6d5d237e87fe9';

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
