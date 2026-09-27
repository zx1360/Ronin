// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'network_config_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$serverReachableHash() => r'627246f42d008e83985b4dbf9641bc911d283bf7';

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

/// 单个服务器地址的连通性探测（"host:port" 为键）
///
/// keepAlive 保证页面重建不会反复重测；地址或 API Key 变化时自动重新探测，
/// 也可通过 `ref.invalidate(serverReachableProvider(address))` 手动刷新.
///
/// Copied from [serverReachable].
@ProviderFor(serverReachable)
const serverReachableProvider = ServerReachableFamily();

/// 单个服务器地址的连通性探测（"host:port" 为键）
///
/// keepAlive 保证页面重建不会反复重测；地址或 API Key 变化时自动重新探测，
/// 也可通过 `ref.invalidate(serverReachableProvider(address))` 手动刷新.
///
/// Copied from [serverReachable].
class ServerReachableFamily extends Family<AsyncValue<bool>> {
  /// 单个服务器地址的连通性探测（"host:port" 为键）
  ///
  /// keepAlive 保证页面重建不会反复重测；地址或 API Key 变化时自动重新探测，
  /// 也可通过 `ref.invalidate(serverReachableProvider(address))` 手动刷新.
  ///
  /// Copied from [serverReachable].
  const ServerReachableFamily();

  /// 单个服务器地址的连通性探测（"host:port" 为键）
  ///
  /// keepAlive 保证页面重建不会反复重测；地址或 API Key 变化时自动重新探测，
  /// 也可通过 `ref.invalidate(serverReachableProvider(address))` 手动刷新.
  ///
  /// Copied from [serverReachable].
  ServerReachableProvider call(
    String address,
  ) {
    return ServerReachableProvider(
      address,
    );
  }

  @override
  ServerReachableProvider getProviderOverride(
    covariant ServerReachableProvider provider,
  ) {
    return call(
      provider.address,
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
  String? get name => r'serverReachableProvider';
}

/// 单个服务器地址的连通性探测（"host:port" 为键）
///
/// keepAlive 保证页面重建不会反复重测；地址或 API Key 变化时自动重新探测，
/// 也可通过 `ref.invalidate(serverReachableProvider(address))` 手动刷新.
///
/// Copied from [serverReachable].
class ServerReachableProvider extends FutureProvider<bool> {
  /// 单个服务器地址的连通性探测（"host:port" 为键）
  ///
  /// keepAlive 保证页面重建不会反复重测；地址或 API Key 变化时自动重新探测，
  /// 也可通过 `ref.invalidate(serverReachableProvider(address))` 手动刷新.
  ///
  /// Copied from [serverReachable].
  ServerReachableProvider(
    String address,
  ) : this._internal(
          (ref) => serverReachable(
            ref as ServerReachableRef,
            address,
          ),
          from: serverReachableProvider,
          name: r'serverReachableProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$serverReachableHash,
          dependencies: ServerReachableFamily._dependencies,
          allTransitiveDependencies:
              ServerReachableFamily._allTransitiveDependencies,
          address: address,
        );

  ServerReachableProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.address,
  }) : super.internal();

  final String address;

  @override
  Override overrideWith(
    FutureOr<bool> Function(ServerReachableRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ServerReachableProvider._internal(
        (ref) => create(ref as ServerReachableRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        address: address,
      ),
    );
  }

  @override
  FutureProviderElement<bool> createElement() {
    return _ServerReachableProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ServerReachableProvider && other.address == address;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, address.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin ServerReachableRef on FutureProviderRef<bool> {
  /// The parameter `address` of this provider.
  String get address;
}

class _ServerReachableProviderElement extends FutureProviderElement<bool>
    with ServerReachableRef {
  _ServerReachableProviderElement(super.provider);

  @override
  String get address => (origin as ServerReachableProvider).address;
}

String _$networkConfigManagerHash() =>
    r'a53702f0f0c9f6cbf9b1b44eaf6e84c095377942';

/// 网络配置管理Provider
///
/// Copied from [NetworkConfigManager].
@ProviderFor(NetworkConfigManager)
final networkConfigManagerProvider =
    NotifierProvider<NetworkConfigManager, NetworkConfigState>.internal(
  NetworkConfigManager.new,
  name: r'networkConfigManagerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$networkConfigManagerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$NetworkConfigManager = Notifier<NetworkConfigState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
