// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'network_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$saveFromRelativeUrlsHash() =>
    r'eb4909b9cf64bd89ab9021ba93a825a11b91b464';

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

/// See also [saveFromRelativeUrls].
@ProviderFor(saveFromRelativeUrls)
const saveFromRelativeUrlsProvider = SaveFromRelativeUrlsFamily();

/// See also [saveFromRelativeUrls].
class SaveFromRelativeUrlsFamily extends Family<AsyncValue<void>> {
  /// See also [saveFromRelativeUrls].
  const SaveFromRelativeUrlsFamily();

  /// See also [saveFromRelativeUrls].
  SaveFromRelativeUrlsProvider call({
    required List<String> urls,
    required String relativeDir,
  }) {
    return SaveFromRelativeUrlsProvider(
      urls: urls,
      relativeDir: relativeDir,
    );
  }

  @override
  SaveFromRelativeUrlsProvider getProviderOverride(
    covariant SaveFromRelativeUrlsProvider provider,
  ) {
    return call(
      urls: provider.urls,
      relativeDir: provider.relativeDir,
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
  String? get name => r'saveFromRelativeUrlsProvider';
}

/// See also [saveFromRelativeUrls].
class SaveFromRelativeUrlsProvider extends AutoDisposeFutureProvider<void> {
  /// See also [saveFromRelativeUrls].
  SaveFromRelativeUrlsProvider({
    required List<String> urls,
    required String relativeDir,
  }) : this._internal(
          (ref) => saveFromRelativeUrls(
            ref as SaveFromRelativeUrlsRef,
            urls: urls,
            relativeDir: relativeDir,
          ),
          from: saveFromRelativeUrlsProvider,
          name: r'saveFromRelativeUrlsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$saveFromRelativeUrlsHash,
          dependencies: SaveFromRelativeUrlsFamily._dependencies,
          allTransitiveDependencies:
              SaveFromRelativeUrlsFamily._allTransitiveDependencies,
          urls: urls,
          relativeDir: relativeDir,
        );

  SaveFromRelativeUrlsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.urls,
    required this.relativeDir,
  }) : super.internal();

  final List<String> urls;
  final String relativeDir;

  @override
  Override overrideWith(
    FutureOr<void> Function(SaveFromRelativeUrlsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: SaveFromRelativeUrlsProvider._internal(
        (ref) => create(ref as SaveFromRelativeUrlsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        urls: urls,
        relativeDir: relativeDir,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<void> createElement() {
    return _SaveFromRelativeUrlsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SaveFromRelativeUrlsProvider &&
        other.urls == urls &&
        other.relativeDir == relativeDir;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, urls.hashCode);
    hash = _SystemHash.combine(hash, relativeDir.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin SaveFromRelativeUrlsRef on AutoDisposeFutureProviderRef<void> {
  /// The parameter `urls` of this provider.
  List<String> get urls;

  /// The parameter `relativeDir` of this provider.
  String get relativeDir;
}

class _SaveFromRelativeUrlsProviderElement
    extends AutoDisposeFutureProviderElement<void>
    with SaveFromRelativeUrlsRef {
  _SaveFromRelativeUrlsProviderElement(super.provider);

  @override
  List<String> get urls => (origin as SaveFromRelativeUrlsProvider).urls;
  @override
  String get relativeDir =>
      (origin as SaveFromRelativeUrlsProvider).relativeDir;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
