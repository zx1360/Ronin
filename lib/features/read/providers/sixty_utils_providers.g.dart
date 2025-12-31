// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sixty_utils_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$moyuDailyHash() => r'f3a59d5b2ce6d7a21c36a993758ff44aab8f5ca5';

/// See also [moyuDaily].
@ProviderFor(moyuDaily)
final moyuDailyProvider = AutoDisposeFutureProvider<Json>.internal(
  moyuDaily,
  name: r'moyuDailyProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$moyuDailyHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef MoyuDailyRef = AutoDisposeFutureProviderRef<Json>;
String _$lyricSearchHash() => r'62ddc4f4e9fe704e3c6ff2d82bd214aed3d74870';

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

/// See also [lyricSearch].
@ProviderFor(lyricSearch)
const lyricSearchProvider = LyricSearchFamily();

/// See also [lyricSearch].
class LyricSearchFamily extends Family<AsyncValue<Json>> {
  /// See also [lyricSearch].
  const LyricSearchFamily();

  /// See also [lyricSearch].
  LyricSearchProvider call(
    String query,
  ) {
    return LyricSearchProvider(
      query,
    );
  }

  @override
  LyricSearchProvider getProviderOverride(
    covariant LyricSearchProvider provider,
  ) {
    return call(
      provider.query,
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
  String? get name => r'lyricSearchProvider';
}

/// See also [lyricSearch].
class LyricSearchProvider extends AutoDisposeFutureProvider<Json> {
  /// See also [lyricSearch].
  LyricSearchProvider(
    String query,
  ) : this._internal(
          (ref) => lyricSearch(
            ref as LyricSearchRef,
            query,
          ),
          from: lyricSearchProvider,
          name: r'lyricSearchProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$lyricSearchHash,
          dependencies: LyricSearchFamily._dependencies,
          allTransitiveDependencies:
              LyricSearchFamily._allTransitiveDependencies,
          query: query,
        );

  LyricSearchProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.query,
  }) : super.internal();

  final String query;

  @override
  Override overrideWith(
    FutureOr<Json> Function(LyricSearchRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: LyricSearchProvider._internal(
        (ref) => create(ref as LyricSearchRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        query: query,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<Json> createElement() {
    return _LyricSearchProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is LyricSearchProvider && other.query == query;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, query.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin LyricSearchRef on AutoDisposeFutureProviderRef<Json> {
  /// The parameter `query` of this provider.
  String get query;
}

class _LyricSearchProviderElement extends AutoDisposeFutureProviderElement<Json>
    with LyricSearchRef {
  _LyricSearchProviderElement(super.provider);

  @override
  String get query => (origin as LyricSearchProvider).query;
}

String _$baikeEntryHash() => r'0ac0f3dec3dd285db2a8c1ed9eab5e0ed701a093';

/// See also [baikeEntry].
@ProviderFor(baikeEntry)
const baikeEntryProvider = BaikeEntryFamily();

/// See also [baikeEntry].
class BaikeEntryFamily extends Family<AsyncValue<Json>> {
  /// See also [baikeEntry].
  const BaikeEntryFamily();

  /// See also [baikeEntry].
  BaikeEntryProvider call(
    String word,
  ) {
    return BaikeEntryProvider(
      word,
    );
  }

  @override
  BaikeEntryProvider getProviderOverride(
    covariant BaikeEntryProvider provider,
  ) {
    return call(
      provider.word,
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
  String? get name => r'baikeEntryProvider';
}

/// See also [baikeEntry].
class BaikeEntryProvider extends AutoDisposeFutureProvider<Json> {
  /// See also [baikeEntry].
  BaikeEntryProvider(
    String word,
  ) : this._internal(
          (ref) => baikeEntry(
            ref as BaikeEntryRef,
            word,
          ),
          from: baikeEntryProvider,
          name: r'baikeEntryProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$baikeEntryHash,
          dependencies: BaikeEntryFamily._dependencies,
          allTransitiveDependencies:
              BaikeEntryFamily._allTransitiveDependencies,
          word: word,
        );

  BaikeEntryProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.word,
  }) : super.internal();

  final String word;

  @override
  Override overrideWith(
    FutureOr<Json> Function(BaikeEntryRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: BaikeEntryProvider._internal(
        (ref) => create(ref as BaikeEntryRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        word: word,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<Json> createElement() {
    return _BaikeEntryProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is BaikeEntryProvider && other.word == word;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, word.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin BaikeEntryRef on AutoDisposeFutureProviderRef<Json> {
  /// The parameter `word` of this provider.
  String get word;
}

class _BaikeEntryProviderElement extends AutoDisposeFutureProviderElement<Json>
    with BaikeEntryRef {
  _BaikeEntryProviderElement(super.provider);

  @override
  String get word => (origin as BaikeEntryProvider).word;
}

String _$healthAnalysisHash() => r'd7ee67b78b0b30157791b06e145b4504657fc254';

/// See also [healthAnalysis].
@ProviderFor(healthAnalysis)
const healthAnalysisProvider = HealthAnalysisFamily();

/// See also [healthAnalysis].
class HealthAnalysisFamily extends Family<AsyncValue<Json>> {
  /// See also [healthAnalysis].
  const HealthAnalysisFamily();

  /// See also [healthAnalysis].
  HealthAnalysisProvider call(
    ({int age, String gender, int height, int weight}) params,
  ) {
    return HealthAnalysisProvider(
      params,
    );
  }

  @override
  HealthAnalysisProvider getProviderOverride(
    covariant HealthAnalysisProvider provider,
  ) {
    return call(
      provider.params,
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
  String? get name => r'healthAnalysisProvider';
}

/// See also [healthAnalysis].
class HealthAnalysisProvider extends AutoDisposeFutureProvider<Json> {
  /// See also [healthAnalysis].
  HealthAnalysisProvider(
    ({int age, String gender, int height, int weight}) params,
  ) : this._internal(
          (ref) => healthAnalysis(
            ref as HealthAnalysisRef,
            params,
          ),
          from: healthAnalysisProvider,
          name: r'healthAnalysisProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$healthAnalysisHash,
          dependencies: HealthAnalysisFamily._dependencies,
          allTransitiveDependencies:
              HealthAnalysisFamily._allTransitiveDependencies,
          params: params,
        );

  HealthAnalysisProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.params,
  }) : super.internal();

  final ({int age, String gender, int height, int weight}) params;

  @override
  Override overrideWith(
    FutureOr<Json> Function(HealthAnalysisRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: HealthAnalysisProvider._internal(
        (ref) => create(ref as HealthAnalysisRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        params: params,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<Json> createElement() {
    return _HealthAnalysisProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is HealthAnalysisProvider && other.params == params;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, params.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin HealthAnalysisRef on AutoDisposeFutureProviderRef<Json> {
  /// The parameter `params` of this provider.
  ({int age, String gender, int height, int weight}) get params;
}

class _HealthAnalysisProviderElement
    extends AutoDisposeFutureProviderElement<Json> with HealthAnalysisRef {
  _HealthAnalysisProviderElement(super.provider);

  @override
  ({int age, String gender, int height, int weight}) get params =>
      (origin as HealthAnalysisProvider).params;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
