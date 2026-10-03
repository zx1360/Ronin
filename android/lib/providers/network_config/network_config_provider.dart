/// 网络配置管理Provider
///
/// 提供服务器连接配置的统一管理，支持：
/// - 多服务器配置 (增删改切换)
/// - mDNS 自动服务发现
/// - 单个地址的连通性状态 (serverReachableProvider)
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/core/services/network/cert_trust.dart';
import 'package:torrid/core/services/network/mdns_discovery.dart';
import 'package:torrid/core/services/storage/prefs_service.dart';
import 'package:uuid/uuid.dart';

part 'network_config_provider.g.dart';

/// 主机配置
///
/// [id] 是稳定标识: 列表项身份、连通性缓存键都基于它,
/// 避免增删配置后按下标复用组件造成状态错位.
class HostConfig {
  final String id;
  final String host;
  final String port;

  const HostConfig({required this.id, required this.host, required this.port});

  /// 新建配置 (自动分配稳定 ID)
  factory HostConfig.create({String host = '', String port = ''}) {
    return HostConfig(id: const Uuid().v4(), host: host, port: port);
  }

  HostConfig copyWith({String? host, String? port}) {
    return HostConfig(
      id: id,
      host: host ?? this.host,
      port: port ?? this.port,
    );
  }

  /// "host:port", 用于连通性探测键与去重
  String get address => '$host:$port';

  Map<String, dynamic> toJson() => {'id': id, 'host': host, 'port': port};

  factory HostConfig.fromJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      final id = (json['id'] ?? '').toString();
      return HostConfig(
        // 兼容早期没有 id 的持久化数据
        id: id.isEmpty ? const Uuid().v4() : id,
        host: (json['host'] ?? '').toString(),
        port: (json['port'] ?? '').toString(),
      );
    }
    return HostConfig.create();
  }

  bool get isValid => host.isNotEmpty && port.isNotEmpty;
}

/// 网络配置状态
class NetworkConfigState {
  final String apiKey;
  final List<HostConfig> configs;
  final int activeIndex;

  /// 是否正在执行 mDNS 服务发现 (仅用于"发现"按钮的局部进度提示)
  final bool isDiscovering;

  final String? message;

  const NetworkConfigState({
    this.apiKey = '',
    this.configs = const [],
    this.activeIndex = 0,
    this.isDiscovering = false,
    this.message,
  });

  NetworkConfigState copyWith({
    String? apiKey,
    List<HostConfig>? configs,
    int? activeIndex,
    bool? isDiscovering,
    String? message,
    bool clearMessage = false,
  }) {
    return NetworkConfigState(
      apiKey: apiKey ?? this.apiKey,
      configs: configs ?? this.configs,
      activeIndex: activeIndex ?? this.activeIndex,
      isDiscovering: isDiscovering ?? this.isDiscovering,
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
    return config.address;
  }
}

/// 网络配置管理Provider
@Riverpod(keepAlive: true)
class NetworkConfigManager extends _$NetworkConfigManager {
  static const String _hostsKey = 'PC_HOST_LIST';
  static const String _activeIndexKey = 'PC_ACTIVE_INDEX';

  @override
  NetworkConfigState build() {
    // 同步加载持久化配置，保证首个消费者（如 ApiClientManager）能立即拿到有效地址
    return _loadState();
  }

  /// 同步读取持久化配置并组装状态
  ///
  /// 本 Provider 是服务器连接配置的唯一真相源；[ApiClientManager] 通过监听本状态
  /// 派生 ApiClient，任何手动推送都会与之冲突。
  NetworkConfigState _loadState() {
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
        configs.add(HostConfig.create(host: host, port: port));
      }

      // 确保 activeIndex 在有效范围内
      if (activeIndex < 0 || activeIndex >= configs.length) {
        activeIndex = 0;
      }

      return NetworkConfigState(
        apiKey: apiKey,
        configs: configs,
        activeIndex: activeIndex,
      );
    } catch (e) {
      return NetworkConfigState(message: '加载配置失败: $e');
    }
  }

  /// 持久化配置与激活下标
  Future<void> _persist() async {
    final prefs = PrefsService().prefs;
    await prefs.setString(
      _hostsKey,
      jsonEncode(state.configs.map((e) => e.toJson()).toList()),
    );
    await prefs.setInt(_activeIndexKey, state.activeIndex);
  }

  /// 保存API Key
  Future<void> saveApiKey(String apiKey) async {
    final trimmedKey = apiKey.trim();
    await PrefsService().prefs.setString("API_KEY", trimmedKey);
    state = state.copyWith(apiKey: trimmedKey, message: 'API Key已保存');
  }

  /// 保存配置
  Future<void> saveConfig(int index, String host, String port) async {
    if (index < 0 || index >= state.configs.length) return;

    final newConfigs = List<HostConfig>.from(state.configs);
    newConfigs[index] =
        newConfigs[index].copyWith(host: host.trim(), port: port.trim());
    state = state.copyWith(configs: newConfigs);
    await _persist();
    state = state.copyWith(message: '配置已保存');
  }

  /// 激活配置
  Future<void> activateConfig(int index) async {
    if (index < 0 || index >= state.configs.length) return;
    if (index == state.activeIndex) return;

    state = state.copyWith(activeIndex: index);
    await _persist();
    state = state.copyWith(message: '已切换到该配置');
  }

  /// 添加配置
  Future<void> addConfig() async {
    final newConfigs = List<HostConfig>.from(state.configs)
      ..add(HostConfig.create());
    state = state.copyWith(configs: newConfigs);
    await _persist();
  }

  /// 删除配置
  Future<void> removeConfig(int index) async {
    if (index < 0 || index >= state.configs.length) return;
    if (state.configs.length <= 1) return;

    final newConfigs = List<HostConfig>.from(state.configs)..removeAt(index);

    var newActiveIndex = state.activeIndex;
    if (index < newActiveIndex) {
      newActiveIndex--;
    } else if (index == newActiveIndex) {
      newActiveIndex = 0;
    }
    newActiveIndex = newActiveIndex.clamp(0, newConfigs.length - 1);

    state = state.copyWith(configs: newConfigs, activeIndex: newActiveIndex);
    await _persist();
    state = state.copyWith(message: '配置已删除');
  }

  /// 刷新配置（重新从持久化存储读取）
  Future<void> refresh() async {
    state = _loadState();
  }

  /// 清除消息
  void clearMessage() {
    state = state.copyWith(clearMessage: true);
  }

  /// mDNS 服务发现
  ///
  /// 扫描局域网内的 Monarch 服务，若发现的服务地址不在已有配置中，
  /// 则自动添加 (不自动切换激活).
  Future<List<DiscoveredService>> discoverServices() async {
    if (state.isDiscovering) return [];

    state = state.copyWith(isDiscovering: true, message: '正在搜索局域网服务...');

    try {
      final discovered = await MDnsDiscovery.discover();

      if (discovered.isEmpty) {
        state = state.copyWith(
          isDiscovering: false,
          message: '未发现局域网内的 Monarch 服务',
        );
        return discovered;
      }

      // 将发现的服务加入配置 (如不存在)
      int added = 0;
      final existingHosts = state.configs
          .where((c) => c.isValid)
          .map((c) => c.address)
          .toSet();

      final newConfigs = List<HostConfig>.from(state.configs);
      for (final svc in discovered) {
        final key = '${svc.host}:${svc.port}';
        if (!existingHosts.contains(key)) {
          newConfigs.add(HostConfig.create(host: svc.host, port: '${svc.port}'));
          existingHosts.add(key);
          added++;
        }
      }

      if (added > 0) {
        state = state.copyWith(configs: newConfigs, isDiscovering: false);
        await _persist();
        state = state.copyWith(
          isDiscovering: false,
          message: '发现 $added 个新服务，已添加到列表',
        );
      } else {
        state = state.copyWith(
          isDiscovering: false,
          message: '发现的 ${discovered.length} 个服务均已存在',
        );
      }

      return discovered;
    } catch (e) {
      state = state.copyWith(
        isDiscovering: false,
        message: '服务发现失败: $e',
      );
      return [];
    }
  }
}

/// 单个服务器地址的连通性探测（"host:port" 为键）
///
/// keepAlive 保证页面重建不会反复重测；地址或 API Key 变化时自动重新探测，
/// 也可通过 `ref.invalidate(serverReachableProvider(address))` 手动刷新.
@Riverpod(keepAlive: true)
Future<bool> serverReachable(ServerReachableRef ref, String address) async {
  final apiKey =
      ref.watch(networkConfigManagerProvider.select((s) => s.apiKey));

  final dio = CertTrust.createDio(
    options: BaseOptions(
      baseUrl: 'https://$address',
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 8),
      headers:
          apiKey.isNotEmpty ? {'X-API-Key': apiKey} : const <String, String>{},
    ),
  );

  try {
    final resp = await dio.get('/API/test');
    return resp.statusCode == 200;
  } catch (_) {
    return false;
  }
}
