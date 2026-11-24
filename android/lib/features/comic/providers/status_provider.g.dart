// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'status_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(localComics)
final localComicsProvider = LocalComicsProvider._();

final class LocalComicsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ComicInfo>>,
          List<ComicInfo>,
          Stream<List<ComicInfo>>
        >
    with $FutureModifier<List<ComicInfo>>, $StreamProvider<List<ComicInfo>> {
  LocalComicsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localComicsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localComicsHash();

  @$internal
  @override
  $StreamProviderElement<List<ComicInfo>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ComicInfo>> create(Ref ref) {
    return localComics(ref);
  }
}

String _$localComicsHash() => r'7c85edfda6d71deaea156abea82624c5f139d720';

@ProviderFor(comicInfos)
final comicInfosProvider = ComicInfosProvider._();

final class ComicInfosProvider
    extends
        $FunctionalProvider<List<ComicInfo>, List<ComicInfo>, List<ComicInfo>>
    with $Provider<List<ComicInfo>> {
  ComicInfosProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'comicInfosProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$comicInfosHash();

  @$internal
  @override
  $ProviderElement<List<ComicInfo>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<ComicInfo> create(Ref ref) {
    return comicInfos(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<ComicInfo> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<ComicInfo>>(value),
    );
  }
}

String _$comicInfosHash() => r'e45f0dc049b36ec41baa764ef16dae848d68837a';

@ProviderFor(comicProgress)
final comicProgressProvider = ComicProgressFamily._();

final class ComicProgressProvider
    extends
        $FunctionalProvider<
          AsyncValue<ComicPreference>,
          ComicPreference,
          Stream<ComicPreference>
        >
    with $FutureModifier<ComicPreference>, $StreamProvider<ComicPreference> {
  ComicProgressProvider._({
    required ComicProgressFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'comicProgressProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$comicProgressHash();

  @override
  String toString() {
    return r'comicProgressProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<ComicPreference> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<ComicPreference> create(Ref ref) {
    final argument = this.argument as String;
    return comicProgress(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ComicProgressProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$comicProgressHash() => r'7c4e1377653371920220826cc2fed626b345cc56';

final class ComicProgressFamily extends $Family
    with $FunctionalFamilyOverride<Stream<ComicPreference>, String> {
  ComicProgressFamily._()
    : super(
        retry: null,
        name: r'comicProgressProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ComicProgressProvider call(String comicId) =>
      ComicProgressProvider._(argument: comicId, from: this);

  @override
  String toString() => r'comicProgressProvider';
}

@ProviderFor(comicPrefWithComicId)
final comicPrefWithComicIdProvider = ComicPrefWithComicIdFamily._();

final class ComicPrefWithComicIdProvider
    extends
        $FunctionalProvider<ComicPreference, ComicPreference, ComicPreference>
    with $Provider<ComicPreference> {
  ComicPrefWithComicIdProvider._({
    required ComicPrefWithComicIdFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'comicPrefWithComicIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$comicPrefWithComicIdHash();

  @override
  String toString() {
    return r'comicPrefWithComicIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<ComicPreference> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ComicPreference create(Ref ref) {
    final argument = this.argument as String;
    return comicPrefWithComicId(ref, comicId: argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ComicPreference value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ComicPreference>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ComicPrefWithComicIdProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$comicPrefWithComicIdHash() =>
    r'de313419f5de6a88e808cf5dd65f85be31d7fae0';

final class ComicPrefWithComicIdFamily extends $Family
    with $FunctionalFamilyOverride<ComicPreference, String> {
  ComicPrefWithComicIdFamily._()
    : super(
        retry: null,
        name: r'comicPrefWithComicIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ComicPrefWithComicIdProvider call({required String comicId}) =>
      ComicPrefWithComicIdProvider._(argument: comicId, from: this);

  @override
  String toString() => r'comicPrefWithComicIdProvider';
}

@ProviderFor(chaptersWithComicId)
final chaptersWithComicIdProvider = ChaptersWithComicIdFamily._();

final class ChaptersWithComicIdProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ChapterInfo>>,
          List<ChapterInfo>,
          Stream<List<ChapterInfo>>
        >
    with
        $FutureModifier<List<ChapterInfo>>,
        $StreamProvider<List<ChapterInfo>> {
  ChaptersWithComicIdProvider._({
    required ChaptersWithComicIdFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'chaptersWithComicIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$chaptersWithComicIdHash();

  @override
  String toString() {
    return r'chaptersWithComicIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<ChapterInfo>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ChapterInfo>> create(Ref ref) {
    final argument = this.argument as String;
    return chaptersWithComicId(ref, comicId: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ChaptersWithComicIdProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$chaptersWithComicIdHash() =>
    r'e63bbc7059e95fa169cd54d771f0b500a13b8543';

final class ChaptersWithComicIdFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<ChapterInfo>>, String> {
  ChaptersWithComicIdFamily._()
    : super(
        retry: null,
        name: r'chaptersWithComicIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ChaptersWithComicIdProvider call({required String comicId}) =>
      ChaptersWithComicIdProvider._(argument: comicId, from: this);

  @override
  String toString() => r'chaptersWithComicIdProvider';
}
