// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'box_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$comicPrefBoxHash() => r'28a333556b142f4cb37512f8252d44dff54bbd23';

/// 漫画阅读偏好的 Hive Box
///
/// Copied from [comicPrefBox].
@ProviderFor(comicPrefBox)
final comicPrefBoxProvider = AutoDisposeProvider<Box<ComicPreference>>.internal(
  comicPrefBox,
  name: r'comicPrefBoxProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$comicPrefBoxHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef ComicPrefBoxRef = AutoDisposeProviderRef<Box<ComicPreference>>;
String _$comicPrefStreamHash() => r'ed650de53bf0529a2b5ad455b5b32df96a3ae23d';

/// 漫画阅读偏好的响应式流
///
/// Copied from [comicPrefStream].
@ProviderFor(comicPrefStream)
final comicPrefStreamProvider =
    AutoDisposeStreamProvider<List<ComicPreference>>.internal(
  comicPrefStream,
  name: r'comicPrefStreamProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$comicPrefStreamHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef ComicPrefStreamRef
    = AutoDisposeStreamProviderRef<List<ComicPreference>>;
String _$comicInfoBoxHash() => r'9fe4133955c8a2583108903f3af2b3b8335f3ba1';

/// 漫画信息的 Hive Box
///
/// Copied from [comicInfoBox].
@ProviderFor(comicInfoBox)
final comicInfoBoxProvider = AutoDisposeProvider<Box<ComicInfo>>.internal(
  comicInfoBox,
  name: r'comicInfoBoxProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$comicInfoBoxHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef ComicInfoBoxRef = AutoDisposeProviderRef<Box<ComicInfo>>;
String _$comicInfoStreamHash() => r'd1886fce50cfd6fabbe7a8ed83be682342aaa2d4';

/// 漫画信息的响应式流
///
/// Copied from [comicInfoStream].
@ProviderFor(comicInfoStream)
final comicInfoStreamProvider =
    AutoDisposeStreamProvider<List<ComicInfo>>.internal(
  comicInfoStream,
  name: r'comicInfoStreamProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$comicInfoStreamHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef ComicInfoStreamRef = AutoDisposeStreamProviderRef<List<ComicInfo>>;
String _$chapterInfoBoxHash() => r'001da9fff0d8764bf70355e2f36c6ec34c4063a7';

/// 章节信息的 Hive Box
///
/// Copied from [chapterInfoBox].
@ProviderFor(chapterInfoBox)
final chapterInfoBoxProvider = AutoDisposeProvider<Box<ChapterInfo>>.internal(
  chapterInfoBox,
  name: r'chapterInfoBoxProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$chapterInfoBoxHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef ChapterInfoBoxRef = AutoDisposeProviderRef<Box<ChapterInfo>>;
String _$chapterInfoStreamHash() => r'ddc2ca7ba80abee38a6146970e12d1763d3b856d';

/// 章节信息的响应式流
///
/// Copied from [chapterInfoStream].
@ProviderFor(chapterInfoStream)
final chapterInfoStreamProvider =
    AutoDisposeStreamProvider<List<ChapterInfo>>.internal(
  chapterInfoStream,
  name: r'chapterInfoStreamProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$chapterInfoStreamHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef ChapterInfoStreamRef = AutoDisposeStreamProviderRef<List<ChapterInfo>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
