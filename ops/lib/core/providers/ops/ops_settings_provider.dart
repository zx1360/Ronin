import 'dart:async';

import 'package:northstar/core/providers/ops/core_services_provider.dart';
import 'package:northstar/domain/ops/models/ops_settings.dart';
import 'package:northstar/services/cert_trust.dart';
import 'package:northstar/services/mdns_discovery.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ops_settings_provider.g.dart';

@Riverpod(keepAlive: true)
class OpsSettingsController extends _$OpsSettingsController {
  @override
  OpsSettings build() {
    // 配置在 main() 预载完成，这里同步取持久化值：若在 build 里异步补载，
    // 首个请求会先带默认配置发出（连错端口/端口），启动后必须手动刷新才能恢复。
    final cached = ref.read(opsPersistenceRepositoryProvider).settings;
    final settings = cached ?? OpsSettings.defaults();
    CertTrust.setApiKey(settings.apiKey);
    CertTrust.setServerBaseUrl(settings.apiBaseUrl);
    return settings;
  }

  /// 保存配置；返回是否成功落盘（false 时 UI 应如实提示，而不是谎报已保存）。
  Future<bool> update({
    String? apiBaseUrl,
    String? apiKey,
    int? autoRefreshSeconds,
    bool? hideApiKey,
  }) async {
    state = state.copyWith(
      apiBaseUrl: apiBaseUrl,
      apiKey: apiKey,
      autoRefreshSeconds: autoRefreshSeconds,
      hideApiKey: hideApiKey,
    );
    CertTrust.setApiKey(state.apiKey);
    CertTrust.setServerBaseUrl(state.apiBaseUrl);
    return _save();
  }

  /// mDNS 服务发现 + localhost 兜底
  ///
  /// 1. 优先通过 mDNS 组播扫描局域网内的 Monarch 服务
  /// 2. 若未发现，在同机上尝试 TCP 探测 localhost 常见端口
  ///
  /// 发现后替换当前服务器地址设置，返回新 URL。
  Future<String?> discoverService() async {
    // 1. mDNS 组播发现
    try {
      final discovered = await MDnsDiscovery.discover();
      if (discovered.isNotEmpty) {
        final svc = discovered.first;
        final newUrl = svc.baseUrl;
        await update(apiBaseUrl: newUrl);
        return newUrl;
      }
    } catch (_) {
      // mDNS 不可用，继续尝试 localhost
    }

    // 2. localhost 兜底：探测本机 Monarch 服务
    try {
      final localUrl = await _probeLocalhost();
      if (localUrl != null) {
        await update(apiBaseUrl: localUrl);
        return localUrl;
      }
    } catch (_) {
      // 探测失败
    }

    return null;
  }

  /// 探测 localhost 上 Monarch 的常见端口
  Future<String?> _probeLocalhost() async {
    // 尝试连接 localhost 上的 Monarch 常见端口
    const candidates = [
      'https://127.0.0.1:7274', // 生产模式 HTTPS
      'http://127.0.0.1:7275', // 开发模式 HTTP
    ];

    for (final url in candidates) {
      try {
        final uri = Uri.parse(url);
        final client = CertTrust.createSecureClient(
          connectionTimeout: const Duration(seconds: 2),
        );
        try {
          final request = await client.getUrl(uri.replace(path: '/API/test'));
          // 当前配置的地址可能不是被探测的端口，全局注入不会命中，这里显式带上。
          final apiKey = CertTrust.apiKey;
          if (apiKey != null) {
            request.headers.set('X-API-Key', apiKey);
          }
          final response = await request.close().timeout(
            const Duration(seconds: 2),
          );
          if (response.statusCode == 200) {
            return url;
          }
        } finally {
          client.close(force: true);
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  Future<bool> _save() async {
    final repository = ref.read(opsPersistenceRepositoryProvider);
    return repository.saveSettings(state);
  }
}
