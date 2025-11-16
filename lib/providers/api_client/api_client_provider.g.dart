// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_client_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$fetcherHash() => r'b351e0590270c8f560e4658392091daa7b19bccc';

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
    CancelToken? cancelToken,
    void Function(int, int)? onReceiveProgress,
  }) {
    return FetcherProvider(
      path: path,
      params: params,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
    );
  }

  @override
  FetcherProvider getProviderOverride(
    covariant FetcherProvider provider,
  ) {
    return call(
      path: provider.path,
      params: provider.params,
      cancelToken: provider.cancelToken,
      onReceiveProgress: provider.onReceiveProgress,
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
    CancelToken? cancelToken,
    void Function(int, int)? onReceiveProgress,
  }) : this._internal(
          (ref) => fetcher(
            ref as FetcherRef,
            path: path,
            params: params,
            cancelToken: cancelToken,
            onReceiveProgress: onReceiveProgress,
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
          cancelToken: cancelToken,
          onReceiveProgress: onReceiveProgress,
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
    required this.cancelToken,
    required this.onReceiveProgress,
  }) : super.internal();

  final String path;
  final Map<String, dynamic>? params;
  final CancelToken? cancelToken;
  final void Function(int, int)? onReceiveProgress;

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
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
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
        other.params == params &&
        other.cancelToken == cancelToken &&
        other.onReceiveProgress == onReceiveProgress;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, path.hashCode);
    hash = _SystemHash.combine(hash, params.hashCode);
    hash = _SystemHash.combine(hash, cancelToken.hashCode);
    hash = _SystemHash.combine(hash, onReceiveProgress.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin FetcherRef on AutoDisposeFutureProviderRef<Response?> {
  /// The parameter `path` of this provider.
  String get path;

  /// The parameter `params` of this provider.
  Map<String, dynamic>? get params;

  /// The parameter `cancelToken` of this provider.
  CancelToken? get cancelToken;

  /// The parameter `onReceiveProgress` of this provider.
  void Function(int, int)? get onReceiveProgress;
}

class _FetcherProviderElement
    extends AutoDisposeFutureProviderElement<Response?> with FetcherRef {
  _FetcherProviderElement(super.provider);

  @override
  String get path => (origin as FetcherProvider).path;
  @override
  Map<String, dynamic>? get params => (origin as FetcherProvider).params;
  @override
  CancelToken? get cancelToken => (origin as FetcherProvider).cancelToken;
  @override
  void Function(int, int)? get onReceiveProgress =>
      (origin as FetcherProvider).onReceiveProgress;
}

String _$senderHash() => r'95d5c4e4225269bd2e243fb1b5ede9b4021e9d9b';

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
    Map<String, dynamic>? jsonData,
    List<File>? files,
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
  }) {
    return SenderProvider(
      path: path,
      jsonData: jsonData,
      files: files,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
    );
  }

  @override
  SenderProvider getProviderOverride(
    covariant SenderProvider provider,
  ) {
    return call(
      path: provider.path,
      jsonData: provider.jsonData,
      files: provider.files,
      cancelToken: provider.cancelToken,
      onSendProgress: provider.onSendProgress,
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
    Map<String, dynamic>? jsonData,
    List<File>? files,
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
  }) : this._internal(
          (ref) => sender(
            ref as SenderRef,
            path: path,
            jsonData: jsonData,
            files: files,
            cancelToken: cancelToken,
            onSendProgress: onSendProgress,
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
          jsonData: jsonData,
          files: files,
          cancelToken: cancelToken,
          onSendProgress: onSendProgress,
        );

  SenderProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.path,
    required this.jsonData,
    required this.files,
    required this.cancelToken,
    required this.onSendProgress,
  }) : super.internal();

  final String path;
  final Map<String, dynamic>? jsonData;
  final List<File>? files;
  final CancelToken? cancelToken;
  final void Function(int, int)? onSendProgress;

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
        jsonData: jsonData,
        files: files,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
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
        other.jsonData == jsonData &&
        other.files == files &&
        other.cancelToken == cancelToken &&
        other.onSendProgress == onSendProgress;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, path.hashCode);
    hash = _SystemHash.combine(hash, jsonData.hashCode);
    hash = _SystemHash.combine(hash, files.hashCode);
    hash = _SystemHash.combine(hash, cancelToken.hashCode);
    hash = _SystemHash.combine(hash, onSendProgress.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin SenderRef on AutoDisposeFutureProviderRef<Response?> {
  /// The parameter `path` of this provider.
  String get path;

  /// The parameter `jsonData` of this provider.
  Map<String, dynamic>? get jsonData;

  /// The parameter `files` of this provider.
  List<File>? get files;

  /// The parameter `cancelToken` of this provider.
  CancelToken? get cancelToken;

  /// The parameter `onSendProgress` of this provider.
  void Function(int, int)? get onSendProgress;
}

class _SenderProviderElement extends AutoDisposeFutureProviderElement<Response?>
    with SenderRef {
  _SenderProviderElement(super.provider);

  @override
  String get path => (origin as SenderProvider).path;
  @override
  Map<String, dynamic>? get jsonData => (origin as SenderProvider).jsonData;
  @override
  List<File>? get files => (origin as SenderProvider).files;
  @override
  CancelToken? get cancelToken => (origin as SenderProvider).cancelToken;
  @override
  void Function(int, int)? get onSendProgress =>
      (origin as SenderProvider).onSendProgress;
}

String _$apiClientManagerHash() => r'f8257c3a9cac885975e56451619b341b82511048';

/// See also [ApiClientManager].
@ProviderFor(ApiClientManager)
final apiClientManagerProvider =
    NotifierProvider<ApiClientManager, ApiClient>.internal(
  ApiClientManager.new,
  name: r'apiClientManagerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$apiClientManagerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ApiClientManager = Notifier<ApiClient>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
