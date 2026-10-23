// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_client_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$apiClientManagerHash() => r'1100308080b7a552020de68cd69049e4c17cda58';

/// 仅在活跃配置或 API key 变化时重建客户端。
///
/// Copied from [ApiClientManager].
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
