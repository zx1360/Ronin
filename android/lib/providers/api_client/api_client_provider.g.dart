// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_client_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 仅在活跃配置或 API key 变化时重建客户端。

@ProviderFor(ApiClientManager)
final apiClientManagerProvider = ApiClientManagerProvider._();

/// 仅在活跃配置或 API key 变化时重建客户端。
final class ApiClientManagerProvider
    extends $NotifierProvider<ApiClientManager, ApiClient> {
  /// 仅在活跃配置或 API key 变化时重建客户端。
  ApiClientManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'apiClientManagerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$apiClientManagerHash();

  @$internal
  @override
  ApiClientManager create() => ApiClientManager();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ApiClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ApiClient>(value),
    );
  }
}

String _$apiClientManagerHash() => r'1100308080b7a552020de68cd69049e4c17cda58';

/// 仅在活跃配置或 API key 变化时重建客户端。

abstract class _$ApiClientManager extends $Notifier<ApiClient> {
  ApiClient build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ApiClient, ApiClient>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ApiClient, ApiClient>,
              ApiClient,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
