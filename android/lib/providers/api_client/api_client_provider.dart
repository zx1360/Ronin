import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/core/services/network/api_client.dart';
import 'package:torrid/providers/network_config/network_config_provider.dart';

part 'api_client_provider.g.dart';

/// 仅在活跃配置或 API key 变化时重建客户端。
@Riverpod(keepAlive: true)
class ApiClientManager extends _$ApiClientManager {
  @override
  ApiClient build() {
    final activeConfig = ref.watch(
      networkConfigManagerProvider.select((s) => s.activeConfig),
    );
    final apiKey = ref.watch(
      networkConfigManagerProvider.select((s) => s.apiKey),
    );

    final baseUrl = (activeConfig != null && activeConfig.isValid)
        ? 'https://${activeConfig.host}:${activeConfig.port}'
        : '';
    final client = ApiClient(
      baseUrl: baseUrl,
      apiKey: apiKey.isEmpty ? null : apiKey,
    );
    ref.onDispose(client.close);
    return client;
  }
}
