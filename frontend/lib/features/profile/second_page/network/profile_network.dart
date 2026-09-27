import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/app/theme/theme_book.dart';
import 'package:torrid/core/constants/spacing.dart';
import 'package:torrid/providers/network_config/network_config_provider.dart';

/// 网络设置页面
///
/// 提供服务器连接配置，包括：
/// - API Key 设置
/// - 服务器地址配置（IP/端口）与多配置管理
/// - 局域网服务发现
///
/// 每个配置的连接状态由 [serverReachableProvider] 按地址派生，页面重建不会
/// 造成状态错位或重复探测.
class ProfileNetwork extends ConsumerStatefulWidget {
  const ProfileNetwork({super.key});

  @override
  ConsumerState<ProfileNetwork> createState() => _ProfileNetworkState();
}

class _ProfileNetworkState extends ConsumerState<ProfileNetwork> {
  final _apiKeyController = TextEditingController();
  bool _obscureApiKey = true;

  @override
  void initState() {
    super.initState();
    _apiKeyController.text = ref.read(networkConfigManagerProvider).apiKey;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configState = ref.watch(networkConfigManagerProvider);

    // 监听配置状态变化，同步 API Key 输入框并显示提示消息
    ref.listen(networkConfigManagerProvider, (prev, next) {
      if (prev?.apiKey != next.apiKey && _apiKeyController.text != next.apiKey) {
        _apiKeyController.text = next.apiKey;
      }
      if (next.message != null && next.message != prev?.message) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.message!)),
        );
        ref.read(networkConfigManagerProvider.notifier).clearMessage();
      }
    });

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // API Key 设置
        _buildSection(
          title: 'API Key',
          children: [
            _buildApiKeyTile(),
          ],
        ),

        const SizedBox(height: AppSpacing.lg),

        // 服务器配置
        _buildSection(
          title: '服务器配置',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (configState.isDiscovering)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                TextButton.icon(
                  onPressed: () => ref
                      .read(networkConfigManagerProvider.notifier)
                      .discoverServices(),
                  icon: const Icon(Icons.wifi_find, size: 18),
                  label: const Text('发现'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              const SizedBox(width: 4),
              TextButton.icon(
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
            ],
          ),
          children: [
            for (final entry in configState.configs.asMap().entries) ...[
              if (entry.key > 0) const Divider(height: 1),
              _ServerConfigTile(
                // 以稳定 ID 作为身份, 避免增删配置后组件状态与配置错位
                key: ValueKey(entry.value.id),
                index: entry.key,
                config: entry.value,
                isActive: entry.key == configState.activeIndex,
                canRemove: configState.configs.length > 1,
              ),
            ],
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

  Widget _buildApiKeyTile() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _apiKeyController,
              decoration: InputDecoration(
                hintText: '请输入API Key（可选）',
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                isDense: true,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureApiKey ? Icons.visibility_off : Icons.visibility,
                    size: 18,
                  ),
                  onPressed: () =>
                      setState(() => _obscureApiKey = !_obscureApiKey),
                ),
              ),
              obscureText: _obscureApiKey,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          ElevatedButton(
            onPressed: () => ref
                .read(networkConfigManagerProvider.notifier)
                .saveApiKey(_apiKeyController.text),
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

/// 单个服务器配置项
class _ServerConfigTile extends ConsumerStatefulWidget {
  final int index;
  final HostConfig config;
  final bool isActive;
  final bool canRemove;

  const _ServerConfigTile({
    super.key,
    required this.index,
    required this.config,
    required this.isActive,
    required this.canRemove,
  });

  @override
  ConsumerState<_ServerConfigTile> createState() => _ServerConfigTileState();
}

class _ServerConfigTileState extends ConsumerState<_ServerConfigTile> {
  late final TextEditingController _hostController =
      TextEditingController(text: widget.config.host);
  late final TextEditingController _portController =
      TextEditingController(text: widget.config.port);

  /// 输入内容与已保存配置不一致
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _hostController.addListener(_checkDirty);
    _portController.addListener(_checkDirty);
  }

  @override
  void didUpdateWidget(_ServerConfigTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 配置被外部修改（保存 / 服务发现 / 删除其它项导致下标变化）时同步输入框
    if (!_dirty &&
        (oldWidget.config.id != widget.config.id ||
            oldWidget.config.host != widget.config.host ||
            oldWidget.config.port != widget.config.port)) {
      _hostController.text = widget.config.host;
      _portController.text = widget.config.port;
    }
    _checkDirty();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _checkDirty() {
    final dirty = _hostController.text.trim() != widget.config.host ||
        _portController.text.trim() != widget.config.port;
    if (dirty != _dirty && mounted) setState(() => _dirty = dirty);
  }

  Future<void> _handleSave() async {
    await ref.read(networkConfigManagerProvider.notifier).saveConfig(
          widget.index,
          _hostController.text,
          _portController.text,
        );
  }

  void _testConnection() {
    if (!widget.config.isValid) return;
    ref.invalidate(serverReachableProvider(widget.config.address));
  }

  @override
  Widget build(BuildContext context) {
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
              Expanded(child: _buildStatus()),
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
                onPressed: widget.config.isValid ? _testConnection : null,
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
                onPressed: _dirty ? _handleSave : null,
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

  /// 连接状态：由已保存地址派生，输入未保存时提示"未保存"
  Widget _buildStatus() {
    if (!widget.config.isValid) {
      return const _StatusLabel(color: Colors.grey, text: '未配置');
    }
    if (_dirty) {
      return const _StatusLabel(color: Colors.amber, text: '未保存');
    }

    final reachable = ref.watch(serverReachableProvider(widget.config.address));
    return reachable.when(
      loading: () => const _StatusLabel(
        color: Colors.amber,
        text: '测试中',
        busy: true,
      ),
      error: (_, __) => const _StatusLabel(color: Colors.red, text: '未连接'),
      data: (ok) => _StatusLabel(
        color: ok ? Colors.green : Colors.red,
        text: ok ? '已连接' : '未连接',
      ),
    );
  }
}

/// 连接状态标签
class _StatusLabel extends StatelessWidget {
  final Color color;
  final String text;
  final bool busy;

  const _StatusLabel({
    required this.color,
    required this.text,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, color: color, size: 10),
        const SizedBox(width: 4),
        if (busy)
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        Flexible(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
