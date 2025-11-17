// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'status_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$comicPrefsHash() => r'282d06a77b1093f0208acf5bae0bbf419f319ae8';

/// See also [comicPrefs].
@ProviderFor(comicPrefs)
final comicPrefsProvider = AutoDisposeProvider<List<ComicPreference>>.internal(
  comicPrefs,
  name: r'comicPrefsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$comicPrefsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef ComicPrefsRef = AutoDisposeProviderRef<List<ComicPreference>>;
String _$comicInfosHash() => r'82eae5d4f68dce760a3bab7fb67555f403732655';

/// See also [comicInfos].
@ProviderFor(comicInfos)
final comicInfosProvider = AutoDisposeProvider<List<ComicInfo>>.internal(
  comicInfos,
  name: r'comicInfosProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$comicInfosHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef ComicInfosRef = AutoDisposeProviderRef<List<ComicInfo>>;
String _$chapterInfosHash() => r'7e6e3ed36305cff911a386a5062b8c9bd96e7650';

/// See also [chapterInfos].
@ProviderFor(chapterInfos)
final chapterInfosProvider = AutoDisposeProvider<List<ChapterInfo>>.internal(
  chapterInfos,
  name: r'chapterInfosProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$chapterInfosHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef ChapterInfosRef = AutoDisposeProviderRef<List<ChapterInfo>>;
String _$comicPrefWithComicIdHash() =>
    r'736cccf8254439070d41a733bd17b0f748209aa3';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [comicPrefWithComicId].
@ProviderFor(comicPrefWithComicId)
const comicPrefWithComicIdProvider = ComicPrefWithComicIdFamily();

/// See also [comicPrefWithComicId].
class ComicPrefWithComicIdFamily extends Family<ComicPreference> {
  /// See also [comicPrefWithComicId].
  const ComicPrefWithComicIdFamily();

  /// See also [comicPrefWithComicId].
  ComicPrefWithComicIdProvider call({
    required String comicId,
  }) {
    return ComicPrefWithComicIdProvider(
      comicId: comicId,
    );
  }

  @override
  ComicPrefWithComicIdProvider getProviderOverride(
    covariant ComicPrefWithComicIdProvider provider,
  ) {
    return call(
      comicId: provider.comicId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'comicPrefWithComicIdProvider';
}

/// See also [comicPrefWithComicId].
class ComicPrefWithComicIdProvider
    extends AutoDisposeProvider<ComicPreference> {
  /// See also [comicPrefWithComicId].
  ComicPrefWithComicIdProvider({
    required String comicId,
  }) : this._internal(
          (ref) => comicPrefWithComicId(
            ref as ComicPrefWithComicIdRef,
            comicId: comicId,
          ),
          from: comicPrefWithComicIdProvider,
          name: r'comicPrefWithComicIdProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$comicPrefWithComicIdHash,
          dependencies: ComicPrefWithComicIdFamily._dependencies,
          allTransitiveDependencies:
              ComicPrefWithComicIdFamily._allTransitiveDependencies,
          comicId: comicId,
        );

  ComicPrefWithComicIdProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.comicId,
  }) : super.internal();

  final String comicId;

  @override
  Override overrideWith(
    ComicPreference Function(ComicPrefWithComicIdRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ComicPrefWithComicIdProvider._internal(
        (ref) => create(ref as ComicPrefWithComicIdRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        comicId: comicId,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<ComicPreference> createElement() {
    return _ComicPrefWithComicIdProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ComicPrefWithComicIdProvider && other.comicId == comicId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, comicId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin ComicPrefWithComicIdRef on AutoDisposeProviderRef<ComicPreference> {
  /// The parameter `comicId` of this provider.
  String get comicId;
}

class _ComicPrefWithComicIdProviderElement
    extends AutoDisposeProviderElement<ComicPreference>
    with ComicPrefWithComicIdRef {
  _ComicPrefWithComicIdProviderElement(super.provider);

  @override
  String get comicId => (origin as ComicPrefWithComicIdProvider).comicId;
}

String _$chaptersWithComicIdHash() =>
    r'087dadc7e63a4f094495d95f24e060868d17937b';

/// See also [chaptersWithComicId].
@ProviderFor(chaptersWithComicId)
const chaptersWithComicIdProvider = ChaptersWithComicIdFamily();

/// See also [chaptersWithComicId].
class ChaptersWithComicIdFamily extends Family<List<ChapterInfo>> {
  /// See also [chaptersWithComicId].
  const ChaptersWithComicIdFamily();

  /// See also [chaptersWithComicId].
  ChaptersWithComicIdProvider call({
    required String comicId,
  }) {
    return ChaptersWithComicIdProvider(
      comicId: comicId,
    );
  }

  @override
  ChaptersWithComicIdProvider getProviderOverride(
    covariant ChaptersWithComicIdProvider provider,
  ) {
    return call(
      comicId: provider.comicId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'chaptersWithComicIdProvider';
}

/// See also [chaptersWithComicId].
class ChaptersWithComicIdProvider
    extends AutoDisposeProvider<List<ChapterInfo>> {
  /// See also [chaptersWithComicId].
  ChaptersWithComicIdProvider({
    required String comicId,
  }) : this._internal(
          (ref) => chaptersWithComicId(
            ref as ChaptersWithComicIdRef,
            comicId: comicId,
          ),
          from: chaptersWithComicIdProvider,
          name: r'chaptersWithComicIdProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$chaptersWithComicIdHash,
          dependencies: ChaptersWithComicIdFamily._dependencies,
          allTransitiveDependencies:
              ChaptersWithComicIdFamily._allTransitiveDependencies,
          comicId: comicId,
        );

  ChaptersWithComicIdProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.comicId,
  }) : super.internal();

  final String comicId;

  @override
  Override overrideWith(
    List<ChapterInfo> Function(ChaptersWithComicIdRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ChaptersWithComicIdProvider._internal(
        (ref) => create(ref as ChaptersWithComicIdRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        comicId: comicId,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<List<ChapterInfo>> createElement() {
    return _ChaptersWithComicIdProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ChaptersWithComicIdProvider && other.comicId == comicId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, comicId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin ChaptersWithComicIdRef on AutoDisposeProviderRef<List<ChapterInfo>> {
  /// The parameter `comicId` of this provider.
  String get comicId;
}

class _ChaptersWithComicIdProviderElement
    extends AutoDisposeProviderElement<List<ChapterInfo>>
    with ChaptersWithComicIdRef {
  _ChaptersWithComicIdProviderElement(super.provider);

  @override
  String get comicId => (origin as ChaptersWithComicIdProvider).comicId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
