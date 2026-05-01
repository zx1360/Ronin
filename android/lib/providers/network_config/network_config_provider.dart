/// 网络配置管理Provider
///
/// 提供服务器连接配置的统一管理
library;

import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/core/services/storage/prefs_service.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

part 'network_config_provider.g.dart';

/// 主机配置
class HostConfig {
  final String host;
  final String port;

  const HostConfig({required this.host, required this.port});

  HostConfig copyWith({String? host, String? port}) {
    return HostConfig(
      host: host ?? this.host,
      port: port ?? this.port,
    );
  }

  Map<String, dynamic> toJson() => {'host': host, 'port': port};

  factory HostConfig.fromJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      return HostConfig(
        host: (json['host'] ?? '').toString(),
        port: (json['port'] ?? '').toString(),
      );
    }
    return const HostConfig(host: '', port: '');
  }

  bool get isValid => host.isNotEmpty && port.isNotEmpty;
}

/// 网络配置状态
class NetworkConfigState {
  final String apiKey;
  final List<HostConfig> configs;
  final int activeIndex;
  final bool isLoading;
  final String? message;

  const NetworkConfigState({
    this.apiKey = '',
    this.configs = const [],
    this.activeIndex = 0,
    this.isLoading = false,
    this.message,
  });

  NetworkConfigState copyWith({
    String? apiKey,
    List<HostConfig>? configs,
    int? activeIndex,
    bool? isLoading,
    String? message,
    bool clearMessage = false,
  }) {
    return NetworkConfigState(
      apiKey: apiKey ?? this.apiKey,
      configs: configs ?? this.configs,
      activeIndex: activeIndex ?? this.activeIndex,
      isLoading: isLoading ?? this.isLoading,
      message: clearMessage ? null : (message ?? this.message),
    );
  }

  /// 获取当前活跃的配置
  HostConfig? get activeConfig {
    if (activeIndex >= 0 && activeIndex < configs.length) {
      return configs[activeIndex];
    }
    return null;
  }

  /// 服务器地址（用于显示）
  String get serverAddress {
    final config = activeConfig;
    if (config == null || !config.isValid) return '未配置';
    return '${config.host}:${config.port}';
  }
}

/// 网络配置管理Provider
@Riverpod(keepAlive: true)
class NetworkConfigManager extends _$NetworkConfigManager {
  static const String _hostsKey = 'PC_HOST_LIST';
  static const String _activeIndexKey = 'PC_ACTIVE_INDEX';

  @override
  NetworkConfigState build() {
    // 初始加载配置
    Future.microtask(() => _loadConfigs());
    return const NetworkConfigState(isLoading: true);
  }

  /// 加载配置
  Future<void> _loadConfigs() async {
    try {
      final prefs = PrefsService().prefs;
      final apiKey = prefs.getString("API_KEY") ?? "";
      var activeIndex = prefs.getInt(_activeIndexKey) ?? 0;

      final List<HostConfig> configs = [];
      final raw = prefs.getString(_hostsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          configs.addAll(decoded.map((e) => HostConfig.fromJson(e)));
        }
      }

      // 如果没有配置，尝试从旧的单一配置中迁移
      if (configs.isEmpty) {
        final host = prefs.getString("PC_HOST") ?? "";
        final port = prefs.getString("PC_PORT") ?? "";
        configs.add(HostConfig(host: host, port: port));
      }

      // 确保 activeIndex 在有效范围内
      if (activeIndex >= configs.length) {
        activeIndex = 0;
      }

      state = state.copyWith(
        apiKey: apiKey,
        configs: configs,
        activeIndex: activeIndex,
        isLoading: false,
      );

      // 同步当前活跃配置
      await _syncActiveConfig();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        message: '加载配置失败: $e',
      );
    }
  }

  /// 同步活跃配置到ApiClient
  Future<void> _syncActiveConfig() async {
    final config = state.activeConfig;
    if (config != null && config.isValid) {
      await ref.read(apiClientManagerProvider.notifier).setAddr(
            host: config.host,
            port: config.port,
          );
    }
    await ref.read(apiClientManagerProvider.notifier).setApiKey(
          state.apiKey,
        );
  }

  /// 持久化配置
  Future<void> _persistConfigs() async {
    final prefs = PrefsService().prefs;
    final encoded = jsonEncode(state.configs.map((e) => e.toJson()).toList());
    await prefs.setString(_hostsKey, encoded);
  }

  /// 保存API Key
  Future<void> saveApiKey(String apiKey) async {
    final trimmedKey = apiKey.trim();
    await ref.read(apiClientManagerProvider.notifier).setApiKey(trimmedKey);
    state = state.copyWith(apiKey: trimmedKey, message: 'API Key已保存');
  }

  /// 保存配置
  Future<void> saveConfig(int index, String host, String port) async {
    if (index < 0 || index >= state.configs.length) return;

    final newConfigs = List<HostConfig>.from(state.configs);
    newConfigs[index] = newConfigs[index].copyWith(host: host, port: port);
    state = state.copyWith(configs: newConfigs);
    await _persistConfigs();

    // 如果保存的是当前活跃配置，同步到 apiClientManager
    if (index == state.activeIndex) {
      await _syncActiveConfig();
    }

    state = state.copyWith(message: '配置已保存');
  }

  /// 激活配置
  Future<void> activateConfig(int index) async {
    if (index < 0 || index >= state.configs.length) return;

    final prefs = PrefsService().prefs;
    await prefs.setInt(_activeIndexKey, index);
    state = state.copyWith(activeIndex: index);
    await _syncActiveConfig();
    state = state.copyWith(message: '已切换到该配置');
  }

  /// 添加配置
  Future<void> addConfig() async {
    final newConfigs = List<HostConfig>.from(state.configs);
    newConfigs.add(const HostConfig(host: '', port: ''));
    state = state.copyWith(configs: newConfigs);
    await _persistConfigs();
  }

  /// 删除配置
  Future<void> removeConfig(int index) async {
    if (state.configs.length <= 1) return;

    final newConfigs = List<HostConfig>.from(state.configs);
    newConfigs.removeAt(index);

    var newActiveIndex = state.activeIndex;
    if (newActiveIndex >= newConfigs.length) {
      newActiveIndex = newConfigs.length - 1;
    } else if (index < newActiveIndex) {
      newActiveIndex--;
    } else if (index == newActiveIndex) {
      newActiveIndex = 0;
    }

    state = state.copyWith(configs: newConfigs, activeIndex: newActiveIndex);
    await _persistConfigs();
    await PrefsService().prefs.setInt(_activeIndexKey, newActiveIndex);
    await _syncActiveConfig();
    state = state.copyWith(message: '配置已删除');
  }

  /// 刷新配置
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearMessage: true);
    await _loadConfigs();
  }

  /// 清除消息
  void clearMessage() {
    state = state.copyWith(clearMessage: true);
  }
}
