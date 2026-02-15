import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/app/theme/theme_book.dart';
import 'package:torrid/core/constants/spacing.dart';
import 'package:torrid/providers/network_config/network_config_provider.dart';

/// 网络设置页面
///
/// 提供服务器连接配置，包括：
/// - API Key 设置
/// - 服务器地址配置（IP/端口）
/// - 多配置管理
class ProfileNetwork extends ConsumerStatefulWidget {
  const ProfileNetwork({super.key});

  @override
  ConsumerState<ProfileNetwork> createState() => _ProfileNetworkState();
}

class _ProfileNetworkState extends ConsumerState<ProfileNetwork> {
  final _apiKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final configState = ref.read(networkConfigManagerProvider);
      _apiKeyController.text = configState.apiKey;
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configState = ref.watch(networkConfigManagerProvider);

    // 监听配置状态变化，更新API Key输入框
    ref.listen(networkConfigManagerProvider, (prev, next) {
      if (prev?.apiKey != next.apiKey && _apiKeyController.text != next.apiKey) {
        _apiKeyController.text = next.apiKey;
      }
      // 显示消息
      if (next.message != null && next.message != prev?.message) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.message!)),
        );
        ref.read(networkConfigManagerProvider.notifier).clearMessage();
      }
    });

    if (configState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // API Key 设置
        _buildSection(
          title: 'API Key',
          children: [
            _ApiKeyTile(
              controller: _apiKeyController,
              onSave: () {
                ref
                    .read(networkConfigManagerProvider.notifier)
                    .saveApiKey(_apiKeyController.text);
              },
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.lg),

        // 服务器配置
        _buildSection(
          title: '服务器配置',
          trailing: TextButton.icon(
            onPressed: () =>
                ref.read(networkConfigManagerProvider.notifier).addConfig(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('新增'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          children: [
            ...configState.configs.asMap().entries.map((entry) {
              final index = entry.key;
              final config = entry.value;
              return Column(
                children: [
                  if (index > 0) const Divider(height: 1),
                  _ServerConfigTile(
                    index: index,
                    config: config,
                    apiKey: configState.apiKey,
                    isActive: index == configState.activeIndex,
                    canRemove: configState.configs.length > 1,
                  ),
                ],
              );
            }),
          ],
        ),

        const SizedBox(height: AppSpacing.lg),

        // 说明
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text(
            '提示：配置服务器地址后，可在"数据"页面进行数据同步和备份操作。',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.sm,
            bottom: AppSpacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }
}

/// API Key 设置项
class _ApiKeyTile extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSave;

  const _ApiKeyTile({
    required this.controller,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: '请输入API Key（可选）',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                isDense: true,
              ),
              obscureText: true,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          ElevatedButton(
            onPressed: onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}

/// 服务器配置项
class _ServerConfigTile extends ConsumerStatefulWidget {
  final int index;
  final HostConfig config;
  final String apiKey;
  final bool isActive;
  final bool canRemove;

  const _ServerConfigTile({
    required this.index,
    required this.config,
    required this.apiKey,
    required this.isActive,
    required this.canRemove,
  });

  @override
  ConsumerState<_ServerConfigTile> createState() => _ServerConfigTileState();
}

class _ServerConfigTileState extends ConsumerState<_ServerConfigTile> {
  late TextEditingController _hostController;
  late TextEditingController _portController;
  bool _isTesting = false;
  bool? _isConnected;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController(text: widget.config.host);
    _portController = TextEditingController(text: widget.config.port);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _testConnection();
    });
  }

  @override
  void didUpdateWidget(_ServerConfigTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.host != widget.config.host) {
      _hostController.text = widget.config.host;
    }
    if (oldWidget.config.port != widget.config.port) {
      _portController.text = widget.config.port;
    }
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final host = _hostController.text.trim();
    final port = _portController.text.trim();
    if (host.isEmpty || port.isEmpty) {
      if (mounted) {
        setState(() => _isConnected = null);
      }
      return;
    }

    if (mounted) {
      setState(() => _isTesting = true);
    }

    final dio = Dio(
      BaseOptions(
        baseUrl: 'http://$host:$port',
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 8),
        headers: widget.apiKey.isNotEmpty
            ? {'X-API-Key': widget.apiKey}
            : const {},
      ),
    );

    bool connected = false;
    try {
      final resp = await dio.get('/api/test');
      connected = resp.statusCode == 200;
    } catch (_) {
      connected = false;
    }

    if (mounted) {
      setState(() {
        _isTesting = false;
        _isConnected = connected;
      });
    }
  }

  Future<void> _handleSave() async {
    await ref.read(networkConfigManagerProvider.notifier).saveConfig(
          widget.index,
          _hostController.text.trim(),
          _portController.text.trim(),
        );
    await _testConnection();
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = _isConnected == null
        ? Colors.amber
        : _isConnected!
            ? Colors.green
            : Colors.red;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: widget.isActive
          ? BoxDecoration(
              color: Colors.green.withValues(alpha: 0.05),
              border: Border(
                left: BorderSide(color: Colors.green, width: 3),
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              Text(
                '配置 ${widget.index + 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              // 连接状态指示
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, color: iconColor, size: 10),
                  const SizedBox(width: 4),
                  if (_isTesting)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Text(
                      _isConnected == null
                          ? '未测试'
                          : _isConnected!
                              ? '已连接'
                              : '未连接',
                      style: TextStyle(
                        fontSize: 12,
                        color: iconColor,
                      ),
                    ),
                ],
              ),
              const Spacer(),
              if (widget.isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '当前使用',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // IP地址输入
          TextField(
            controller: _hostController,
            decoration: const InputDecoration(
              labelText: 'IP地址',
              hintText: '例如: 192.168.1.100',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              isDense: true,
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: AppSpacing.sm),

          // 端口输入
          TextField(
            controller: _portController,
            decoration: const InputDecoration(
              labelText: '端口',
              hintText: '例如: 8080',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              isDense: true,
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: AppSpacing.sm),

          // 操作按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _testConnection,
                child: const Text('测试连接'),
              ),
              if (!widget.isActive)
                TextButton(
                  onPressed: () => ref
                      .read(networkConfigManagerProvider.notifier)
                      .activateConfig(widget.index),
                  child: const Text('启用'),
                ),
              if (widget.canRemove)
                TextButton(
                  onPressed: () => ref
                      .read(networkConfigManagerProvider.notifier)
                      .removeConfig(widget.index),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                  child: const Text('删除'),
                ),
              ElevatedButton(
                onPressed: _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('保存'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}