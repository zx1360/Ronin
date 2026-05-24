// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'network_config_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$networkConfigManagerHash() =>
    r'9d2f13aba715ea5673d054bca8a570d1f2c4ec2c';

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
