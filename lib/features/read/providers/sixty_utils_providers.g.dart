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
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
