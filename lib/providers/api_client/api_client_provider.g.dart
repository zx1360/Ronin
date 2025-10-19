// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_client_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$fetcherHash() => r'a26c2f2a68e7248dbd3aec19655fe5569ebbfe91';

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

/// See also [fetcher].
@ProviderFor(fetcher)
const fetcherProvider = FetcherFamily();

/// See also [fetcher].
class FetcherFamily extends Family<AsyncValue<Response?>> {
  /// See also [fetcher].
  const FetcherFamily();

  /// See also [fetcher].
  FetcherProvider call({
    required String path,
    Map<String, dynamic>? params,
  }) {
    return FetcherProvider(
      path: path,
      params: params,
    );
  }

  @override
  FetcherProvider getProviderOverride(
    covariant FetcherProvider provider,
  ) {
    return call(
      path: provider.path,
      params: provider.params,
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
  String? get name => r'fetcherProvider';
}

/// See also [fetcher].
class FetcherProvider extends AutoDisposeFutureProvider<Response?> {
  /// See also [fetcher].
  FetcherProvider({
    required String path,
    Map<String, dynamic>? params,
  }) : this._internal(
          (ref) => fetcher(
            ref as FetcherRef,
            path: path,
            params: params,
          ),
          from: fetcherProvider,
          name: r'fetcherProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$fetcherHash,
          dependencies: FetcherFamily._dependencies,
          allTransitiveDependencies: FetcherFamily._allTransitiveDependencies,
          path: path,
          params: params,
        );

  FetcherProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.path,
    required this.params,
  }) : super.internal();

  final String path;
  final Map<String, dynamic>? params;

  @override
  Override overrideWith(
    FutureOr<Response?> Function(FetcherRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: FetcherProvider._internal(
        (ref) => create(ref as FetcherRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        path: path,
        params: params,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<Response?> createElement() {
    return _FetcherProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is FetcherProvider &&
        other.path == path &&
        other.params == params;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, path.hashCode);
    hash = _SystemHash.combine(hash, params.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin FetcherRef on AutoDisposeFutureProviderRef<Response?> {
  /// The parameter `path` of this provider.
  String get path;

  /// The parameter `params` of this provider.
  Map<String, dynamic>? get params;
}

class _FetcherProviderElement
    extends AutoDisposeFutureProviderElement<Response?> with FetcherRef {
  _FetcherProviderElement(super.provider);

  @override
  String get path => (origin as FetcherProvider).path;
  @override
  Map<String, dynamic>? get params => (origin as FetcherProvider).params;
}

String _$senderHash() => r'9ec8ceba825a5448fb346771713a43ec1bec8df2';

/// See also [sender].
@ProviderFor(sender)
const senderProvider = SenderFamily();

/// See also [sender].
class SenderFamily extends Family<AsyncValue<Response?>> {
  /// See also [sender].
  const SenderFamily();

  /// See also [sender].
  SenderProvider call({
    required String path,
    Map<String, dynamic>? params,
  }) {
    return SenderProvider(
      path: path,
      params: params,
    );
  }

  @override
  SenderProvider getProviderOverride(
    covariant SenderProvider provider,
  ) {
    return call(
      path: provider.path,
      params: provider.params,
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
  String? get name => r'senderProvider';
}

/// See also [sender].
class SenderProvider extends AutoDisposeFutureProvider<Response?> {
  /// See also [sender].
  SenderProvider({
    required String path,
    Map<String, dynamic>? params,
  }) : this._internal(
          (ref) => sender(
            ref as SenderRef,
            path: path,
            params: params,
          ),
          from: senderProvider,
          name: r'senderProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$senderHash,
          dependencies: SenderFamily._dependencies,
          allTransitiveDependencies: SenderFamily._allTransitiveDependencies,
          path: path,
          params: params,
        );

  SenderProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.path,
    required this.params,
  }) : super.internal();

  final String path;
  final Map<String, dynamic>? params;

  @override
  Override overrideWith(
    FutureOr<Response?> Function(SenderRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: SenderProvider._internal(
        (ref) => create(ref as SenderRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        path: path,
        params: params,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<Response?> createElement() {
    return _SenderProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SenderProvider &&
        other.path == path &&
        other.params == params;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, path.hashCode);
    hash = _SystemHash.combine(hash, params.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin SenderRef on AutoDisposeFutureProviderRef<Response?> {
  /// The parameter `path` of this provider.
  String get path;

  /// The parameter `params` of this provider.
  Map<String, dynamic>? get params;
}

class _SenderProviderElement extends AutoDisposeFutureProviderElement<Response?>
    with SenderRef {
  _SenderProviderElement(super.provider);

  @override
  String get path => (origin as SenderProvider).path;
  @override
  Map<String, dynamic>? get params => (origin as SenderProvider).params;
}

String _$apiClientManagerHash() => r'07c9d984069edb8f8396db8f11da08fa20b6f2a0';

/// See also [ApiClientManager].
@ProviderFor(ApiClientManager)
final apiClientManagerProvider =
    AutoDisposeNotifierProvider<ApiClientManager, ApiClient>.internal(
  ApiClientManager.new,
  name: r'apiClientManagerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$apiClientManagerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ApiClientManager = AutoDisposeNotifier<ApiClient>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
