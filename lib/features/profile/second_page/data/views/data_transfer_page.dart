/// 数据传输页面
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/core/services/storage/prefs_service.dart';
import 'package:torrid/features/profile/second_page/data/data_transfer.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';
import 'package:torrid/providers/server_connect/server_conn_provider.dart';

/// 数据传输页面
///
/// 提供数据同步和备份的统一入口，包括：
/// - 网络配置
/// - 传输进度显示
/// - 同步/备份操作按钮
class DataTransferPage extends ConsumerStatefulWidget {
  const DataTransferPage({super.key});

  @override
  ConsumerState<DataTransferPage> createState() => _DataTransferPageState();
}

class _DataTransferPageState extends ConsumerState<DataTransferPage> {
  static const String _hostsKey = 'PC_HOST_LIST';
  static const String _activeIndexKey = 'PC_ACTIVE_INDEX';
  final _apiKeyController = TextEditingController();
  final List<_HostConfig> _configs = [];
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadConfigs();
    });
  }

  void _loadConfigs() {
    final prefs = PrefsService().prefs;
    _apiKeyController.text = prefs.getString("API_KEY") ?? "";
    _activeIndex = prefs.getInt(_activeIndexKey) ?? 0;

    final raw = prefs.getString(_hostsKey);
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        _configs
          ..clear()
          ..addAll(decoded.map((e) => _HostConfig.fromJson(e)));
      }
    }

    if (_configs.isEmpty) {
      final host = prefs.getString("PC_HOST") ?? "";
      final port = prefs.getString("PC_PORT") ?? "";
      _configs.add(_HostConfig(host: host, port: port));
    }

    // 确保 activeIndex 在有效范围内
    if (_activeIndex >= _configs.length) {
      _activeIndex = 0;
    }

    // 初始化时同步当前活跃配置到 apiClientManager
    _syncActiveConfig();

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _syncActiveConfig() async {
    if (_activeIndex < 0 || _activeIndex >= _configs.length) return;
    final config = _configs[_activeIndex];
    // 只有当 host 和 port 都非空时才同步
    if (config.host.isNotEmpty && config.port.isNotEmpty) {
      await ref.read(apiClientManagerProvider.notifier).setAddr(
            host: config.host,
            port: config.port,
          );
    }
    await ref.read(apiClientManagerProvider.notifier).setApiKey(
          _apiKeyController.text.trim(),
        );
  }

  Future<void> _persistConfigs() async {
    final prefs = PrefsService().prefs;
    final encoded = jsonEncode(_configs.map((e) => e.toJson()).toList());
    await prefs.setString(_hostsKey, encoded);
  }

  Future<void> _saveApiKey() async {
    final apiKey = _apiKeyController.text.trim();
    await ref.read(apiClientManagerProvider.notifier).setApiKey(apiKey);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API Key已保存')),
      );
    }
  }

  Future<void> _saveConfig(int index, String host, String port) async {
    if (index < 0 || index >= _configs.length) return;
    _configs[index] = _configs[index].copyWith(host: host, port: port);
    await _persistConfigs();

    // 如果保存的是当前活跃配置，同步到 apiClientManager
    if (index == _activeIndex) {
      await _syncActiveConfig();
    }
  }

  Future<void> _activateConfig(int index) async {
    if (index < 0 || index >= _configs.length) return;
    final prefs = PrefsService().prefs;
    await prefs.setInt(_activeIndexKey, index);
    setState(() {
      _activeIndex = index;
    });
    await _syncActiveConfig();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已切换到该配置')),
      );
    }
  }

  void _addConfig() {
    setState(() {
      _configs.add(const _HostConfig(host: '', port: ''));
    });
    _persistConfigs();
  }

  void _removeConfig(int index) {
    if (_configs.length <= 1) return;
    setState(() {
      _configs.removeAt(index);
      // 调整 activeIndex
      if (_activeIndex >= _configs.length) {
        _activeIndex = _configs.length - 1;
      } else if (index < _activeIndex) {
        _activeIndex--;
      } else if (index == _activeIndex) {
        // 删除的是当前活跃配置，默认切换到第一个
        _activeIndex = 0;
      }
    });
    _persistConfigs();
    PrefsService().prefs.setInt(_activeIndexKey, _activeIndex);
    _syncActiveConfig();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final serverState = ref.watch(serverConnectorProvider);
    final isLoading = serverState['isLoading'] as bool;

    if (isLoading) {
      return _buildLoadingState(theme);
    }

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildApiKeySection(theme),
            const SizedBox(height: 12),

            // 网络配置列表
            ..._configs.asMap().entries.map((entry) {
              final idx = entry.key;
              final config = entry.value;
              return NetworkConfigWidget(
                initialHost: config.host,
                initialPort: config.port,
                apiKey: _apiKeyController.text.trim(),
                canRemove: _configs.length > 1,
                isActive: idx == _activeIndex,
                onRemove: () => _removeConfig(idx),
                onActivate: () => _activateConfig(idx),
                onSave: (host, port) => _saveConfig(idx, host, port),
              );
            }),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addConfig,
                icon: const Icon(Icons.add),
                label: const Text('新增配置'),
              ),
            ),

            // 传输进度
            const TransferProgressWidget(),

            // 同步操作区
            _SectionHeader(title: "同步到本地:", theme: theme),
            const _SyncSection(),

            const SizedBox(height: 24),

            // 备份操作区
            _SectionHeader(title: "更新到外部:", theme: theme),
            const _BackupSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildApiKeySection(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _apiKeyController,
              decoration: const InputDecoration(
                hintText: '请输入API Key (可选)...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.grey),
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              keyboardType: TextInputType.text,
            ),
          ),
          ElevatedButton(
            onPressed: _saveApiKey,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text('保存API Key'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
          ),
          const SizedBox(height: 16),
          const Text("稍等...", style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}

class _HostConfig {
  final String host;
  final String port;

  const _HostConfig({required this.host, required this.port});

  _HostConfig copyWith({String? host, String? port}) {
    return _HostConfig(
      host: host ?? this.host,
      port: port ?? this.port,
    );
  }

  Map<String, dynamic> toJson() => {'host': host, 'port': port};

  factory _HostConfig.fromJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      return _HostConfig(
        host: (json['host'] ?? '').toString(),
        port: (json['port'] ?? '').toString(),
      );
    }
    return const _HostConfig(host: '', port: '');
  }
}

/// 区块标题
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.theme});

  final String title;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.primary,
      ),
    );
  }
}

/// 同步操作区
class _SyncSection extends ConsumerWidget {
  const _SyncSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        const SizedBox(height: 8),
        TransferActionButton(
          action: TransferAction(
            type: TransferType.sync,
            target: TransferTarget.all,
            label: "同步所有",
            highlighted: true,
          ),
          isAll: true,
        ),
        const SizedBox(height: 8),
        TransferActionButton(
          action: TransferAction(
            type: TransferType.sync,
            target: TransferTarget.booklet,
            label: "同步打卡",
          ),
        ),
        const SizedBox(height: 8),
        TransferActionButton(
          action: TransferAction(
            type: TransferType.sync,
            target: TransferTarget.essay,
            label: "同步随笔",
          ),
        ),
      ],
    );
  }
}

/// 备份操作区
class _BackupSection extends ConsumerWidget {
  const _BackupSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        const SizedBox(height: 8),
        TransferActionButton(
          action: TransferAction(
            type: TransferType.backup,
            target: TransferTarget.all,
            label: "备份所有",
            highlighted: true,
          ),
          isAll: true,
        ),
        const SizedBox(height: 8),
        TransferActionButton(
          action: TransferAction(
            type: TransferType.backup,
            target: TransferTarget.booklet,
            label: "备份打卡",
          ),
        ),
        const SizedBox(height: 8),
        TransferActionButton(
          action: TransferAction(
            type: TransferType.backup,
            target: TransferTarget.essay,
            label: "备份随笔",
          ),
        ),
      ],
    );
  }
}
