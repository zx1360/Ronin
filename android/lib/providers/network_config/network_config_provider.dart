import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/core/services/network/cert_trust.dart';
import 'package:torrid/core/services/network/mdns_discovery.dart';
import 'package:torrid/core/services/storage/prefs_service.dart';
import 'package:uuid/uuid.dart';

part 'network_config_provider.g.dart';

/// 用稳定 ID 标识列表项，增删配置时保留对应连接状态。
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
    return HostConfig(id: id, host: host ?? this.host, port: port ?? this.port);
  }

  Uri? get _endpoint {
    final number = int.tryParse(port);
    if (number == null ||
        number < 1 ||
        number > 65535 ||
        host.isEmpty ||
        host.contains(RegExp(r'[\s/?#@\\]'))) {
      return null;
    }
    try {
      return Uri(host: host, port: number);
    } on FormatException {
      return null;
    }
  }

  String get address => _endpoint?.authority ?? '';
  bool get isValid => _endpoint != null;

  Map<String, dynamic> toJson() => {'id': id, 'host': host, 'port': port};

  factory HostConfig.fromJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      return HostConfig(
        id: json['id'] as String,
        host: (json['host'] ?? '').toString(),
        port: (json['port'] ?? '').toString(),
      );
    }
    return HostConfig.create();
  }
}

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

@Riverpod(keepAlive: true)
class NetworkConfigManager extends _$NetworkConfigManager {
  static const String _hostsKey = 'PC_HOST_LIST';
  static const String _activeIndexKey = 'PC_ACTIVE_INDEX';

  @override
  NetworkConfigState build() {
    // 同步加载持久化配置，保证首个消费者（如 ApiClientManager）能立即拿到有效地址
    return _loadState();
  }

  /// ApiClientManager 监听此状态并派生客户端。
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

      if (configs.isEmpty) configs.add(HostConfig.create());

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

  Future<void> _persist() async {
    final prefs = PrefsService().prefs;
    await prefs.setString(
      _hostsKey,
      jsonEncode(state.configs.map((e) => e.toJson()).toList()),
    );
    await prefs.setInt(_activeIndexKey, state.activeIndex);
  }

  Future<void> saveApiKey(String apiKey) async {
    final trimmedKey = apiKey.trim();
    await PrefsService().prefs.setString("API_KEY", trimmedKey);
    state = state.copyWith(apiKey: trimmedKey, message: 'API Key已保存');
  }

  Future<void> saveConfig(int index, String host, String port) async {
    if (index < 0 || index >= state.configs.length) return;

    final newConfigs = List<HostConfig>.from(state.configs);
<<<<<<< HEAD
    newConfigs[index] = newConfigs[index].copyWith(
      host: host.trim(),
      port: port.trim(),
    );
=======
    final updated = newConfigs[index].copyWith(
      host: host.trim(),
      port: port.trim(),
    );
    if (!updated.isValid) {
      state = state.copyWith(message: '请输入有效的主机地址与 HTTPS 端口');
      return;
    }
    newConfigs[index] = updated;
>>>>>>> 1fc83d9 (重构瘦身+分发性.)
    state = state.copyWith(configs: newConfigs);
    await _persist();
    state = state.copyWith(message: '配置已保存');
  }

  Future<void> activateConfig(int index) async {
    if (index < 0 || index >= state.configs.length) return;
    if (index == state.activeIndex) return;

    state = state.copyWith(activeIndex: index);
    await _persist();
    state = state.copyWith(message: '已切换到该配置');
  }

  Future<void> addConfig() async {
    final newConfigs = List<HostConfig>.from(state.configs)
      ..add(HostConfig.create());
    state = state.copyWith(configs: newConfigs);
    await _persist();
  }

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

  Future<void> refresh() async {
    state = _loadState();
  }

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
          message: '未发现局域网内的 Monarch 服务。使用 VPN 时可手动填写服务器地址。',
        );
        return discovered;
      }

      int added = 0;
      final existingHosts = state.configs
          .where((c) => c.isValid)
          .map((c) => c.address)
          .toSet();

      final newConfigs = List<HostConfig>.from(state.configs);
      for (final svc in discovered) {
        final key = Uri(host: svc.host, port: svc.port).authority;
        if (!existingHosts.contains(key)) {
          newConfigs.add(
            HostConfig.create(host: svc.host, port: '${svc.port}'),
          );
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
      state = state.copyWith(isDiscovering: false, message: '服务发现失败: $e');
      return [];
    }
  }
}

/// 单个服务器地址的连通性探测（"host:port" 为键）
///
/// keepAlive 保证页面重建不会反复重测；
/// 也可通过 `ref.invalidate(serverReachableProvider(address))` 手动刷新.
@Riverpod(keepAlive: true)
<<<<<<< HEAD
Future<bool> serverReachable(Ref ref, String address) async {
=======
Future<bool> serverReachable(ServerReachableRef ref, String address) async {
  final apiKey = ref.watch(
    networkConfigManagerProvider.select((s) => s.apiKey),
  );

>>>>>>> 1fc83d9 (重构瘦身+分发性.)
  final dio = CertTrust.createDio(
    options: BaseOptions(
      baseUrl: 'https://$address',
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 8),
<<<<<<< HEAD
=======
      headers: apiKey.isNotEmpty
          ? {'X-API-Key': apiKey}
          : const <String, String>{},
>>>>>>> 1fc83d9 (重构瘦身+分发性.)
    ),
  );

  try {
    final resp = await dio.get('/');
    return resp.statusCode == 200;
  } catch (_) {
    return false;
  } finally {
    dio.close();
  }
}
