// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'network_config_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 网络配置管理Provider

@ProviderFor(NetworkConfigManager)
final networkConfigManagerProvider = NetworkConfigManagerProvider._();

/// 网络配置管理Provider
final class NetworkConfigManagerProvider
    extends $NotifierProvider<NetworkConfigManager, NetworkConfigState> {
  /// 网络配置管理Provider
  NetworkConfigManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'networkConfigManagerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$networkConfigManagerHash();

  @$internal
  @override
  NetworkConfigManager create() => NetworkConfigManager();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NetworkConfigState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NetworkConfigState>(value),
    );
  }
}

String _$networkConfigManagerHash() =>
    r'b7d2c3ef87fcc9bf190050bec47753e89ea0db91';

/// 网络配置管理Provider

abstract class _$NetworkConfigManager extends $Notifier<NetworkConfigState> {
  NetworkConfigState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<NetworkConfigState, NetworkConfigState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<NetworkConfigState, NetworkConfigState>,
              NetworkConfigState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// 单个服务器地址的连通性探测（"host:port" 为键）
///
/// keepAlive 保证页面重建不会反复重测；
/// 也可通过 `ref.invalidate(serverReachableProvider(address))` 手动刷新.

@ProviderFor(serverReachable)
final serverReachableProvider = ServerReachableFamily._();

/// 单个服务器地址的连通性探测（"host:port" 为键）
///
/// keepAlive 保证页面重建不会反复重测；
/// 也可通过 `ref.invalidate(serverReachableProvider(address))` 手动刷新.

final class ServerReachableProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// 单个服务器地址的连通性探测（"host:port" 为键）
  ///
  /// keepAlive 保证页面重建不会反复重测；
  /// 也可通过 `ref.invalidate(serverReachableProvider(address))` 手动刷新.
  ServerReachableProvider._({
    required ServerReachableFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'serverReachableProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$serverReachableHash();

  @override
  String toString() {
    return r'serverReachableProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    final argument = this.argument as String;
    return serverReachable(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ServerReachableProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$serverReachableHash() => r'fd2f7599336467175da5e1acfb673be02c228ded';

/// 单个服务器地址的连通性探测（"host:port" 为键）
///
/// keepAlive 保证页面重建不会反复重测；
/// 也可通过 `ref.invalidate(serverReachableProvider(address))` 手动刷新.

final class ServerReachableFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<bool>, String> {
  ServerReachableFamily._()
    : super(
        retry: null,
        name: r'serverReachableProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// 单个服务器地址的连通性探测（"host:port" 为键）
  ///
  /// keepAlive 保证页面重建不会反复重测；
  /// 也可通过 `ref.invalidate(serverReachableProvider(address))` 手动刷新.

  ServerReachableProvider call(String address) =>
      ServerReachableProvider._(argument: address, from: this);

  @override
  String toString() => r'serverReachableProvider';
}
