import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/core/constants/spacing.dart';
import 'package:torrid/core/services/network/cert_trust.dart';
import 'package:torrid/providers/network_config/network_config_provider.dart';

class ProfileNetwork extends ConsumerStatefulWidget {
  const ProfileNetwork({super.key});

  @override
  ConsumerState<ProfileNetwork> createState() => _ProfileNetworkState();
}

class _ProfileNetworkState extends ConsumerState<ProfileNetwork> {
  late final _apiKey = TextEditingController(
    text: ref.read(networkConfigManagerProvider).apiKey,
  );
  bool _hideKey = true;

  @override
  void dispose() {
    _apiKey.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(networkConfigManagerProvider);
    final manager = ref.read(networkConfigManagerProvider.notifier);
    ref.listen(networkConfigManagerProvider, (previous, next) {
      if (previous?.apiKey != next.apiKey && _apiKey.text != next.apiKey) {
        _apiKey.text = next.apiKey;
      }
      if (next.message case final message? when message != previous?.message) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        manager.clearMessage();
      }
    });

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
<<<<<<< HEAD
        _buildSection(
          title: 'API Key',
=======
        Row(
>>>>>>> 1fc83d9 (重构瘦身+分发性.)
          children: [
            Expanded(
              child: TextField(
                controller: _apiKey,
                obscureText: _hideKey,
                decoration: InputDecoration(
                  labelText: 'API 密钥',
                  suffixIcon: IconButton(
                    tooltip: _hideKey ? '显示密钥' : '隐藏密钥',
                    onPressed: () => setState(() => _hideKey = !_hideKey),
                    icon: Icon(
                      _hideKey ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () => manager.saveApiKey(_apiKey.text),
              child: const Text('保存'),
            ),
          ],
        ),
<<<<<<< HEAD

        const SizedBox(height: AppSpacing.lg),

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
=======
        const SizedBox(height: AppSpacing.md),
        Row(
>>>>>>> 1fc83d9 (重构瘦身+分发性.)
          children: [
            const Expanded(child: Text('服务器配置')),
            TextButton.icon(
              onPressed: state.isDiscovering ? null : manager.discoverServices,
              icon: const Icon(Icons.wifi_find),
              label: Text(state.isDiscovering ? '发现中…' : '发现'),
            ),
            TextButton.icon(
              onPressed: manager.addConfig,
              icon: const Icon(Icons.add),
              label: const Text('新增'),
            ),
          ],
        ),
<<<<<<< HEAD

        const SizedBox(height: AppSpacing.lg),

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
                hintText: '请输入服务端 API Key',
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
=======
        for (final (index, config) in state.configs.indexed)
          _ServerConfigTile(
            key: ValueKey(config.id),
            index: index,
            config: config,
            isActive: index == state.activeIndex,
            canRemove: state.configs.length > 1,
          ),
>>>>>>> 1fc83d9 (重构瘦身+分发性.)
      ],
    );
  }
}

class _ServerConfigTile extends ConsumerStatefulWidget {
  const _ServerConfigTile({
    required super.key,
    required this.index,
    required this.config,
    required this.isActive,
    required this.canRemove,
  });

  final int index;
  final HostConfig config;
  final bool isActive;
  final bool canRemove;

  @override
  ConsumerState<_ServerConfigTile> createState() => _ServerConfigTileState();
}

class _ServerConfigTileState extends ConsumerState<_ServerConfigTile> {
  late final _host = TextEditingController(text: widget.config.host);
  late final _port = TextEditingController(text: widget.config.port);

  bool get _dirty =>
      _host.text.trim() != widget.config.host ||
      _port.text.trim() != widget.config.port;

  @override
  void didUpdateWidget(_ServerConfigTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_host.text.trim() == oldWidget.config.host &&
        _port.text.trim() == oldWidget.config.port) {
      _host.text = widget.config.host;
      _port.text = widget.config.port;
    }
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    super.dispose();
  }

<<<<<<< HEAD
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
=======
  Future<void> _editCertificate() async {
    final address = widget.config.address;
    var value = CertTrust.pinFor(address);
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('证书指纹 · $address'),
        content: TextFormField(
          initialValue: value,
          decoration: const InputDecoration(
            labelText: '从 Northstar 设置页复制 SHA-256 指纹',
          ),
          onChanged: (text) => value = text,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('保存'),
>>>>>>> 1fc83d9 (重构瘦身+分发性.)
          ),
        ],
      ),
    );
    if (save != true || !mounted) return;
    try {
      await CertTrust.savePin(address, value);
      if (mounted) ref.invalidate(serverReachableProvider(address));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败：$error')));
      }
    }
  }
<<<<<<< HEAD
}

class _StatusLabel extends StatelessWidget {
  final Color color;
  final String text;
  final bool busy;

  const _StatusLabel({
    required this.color,
    required this.text,
    this.busy = false,
  });
=======
>>>>>>> 1fc83d9 (重构瘦身+分发性.)

  @override
  Widget build(BuildContext context) {
    final manager = ref.read(networkConfigManagerProvider.notifier);
    final saved = widget.config.isValid && !_dirty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '配置 ${widget.index + 1}${widget.isActive ? ' · 当前使用' : ''}',
                  ),
                ),
                Text(_status()),
              ],
            ),
            TextField(
              controller: _host,
              decoration: const InputDecoration(labelText: '主机或 IP 地址'),
              keyboardType: TextInputType.url,
              onChanged: (_) => setState(() {}),
            ),
            TextField(
              controller: _port,
              decoration: const InputDecoration(labelText: 'HTTPS 端口'),
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
            Wrap(
              alignment: WrapAlignment.end,
              children: [
                TextButton(
                  onPressed: saved ? _editCertificate : null,
                  child: const Text('证书指纹'),
                ),
                TextButton(
                  onPressed: saved
                      ? () => ref.invalidate(
                          serverReachableProvider(widget.config.address),
                        )
                      : null,
                  child: const Text('测试连接'),
                ),
                if (!widget.isActive)
                  TextButton(
                    onPressed: () => manager.activateConfig(widget.index),
                    child: const Text('启用'),
                  ),
                if (widget.canRemove)
                  TextButton(
                    onPressed: () => manager.removeConfig(widget.index),
                    child: const Text('删除'),
                  ),
                FilledButton(
                  onPressed: _dirty
                      ? () => manager.saveConfig(
                          widget.index,
                          _host.text,
                          _port.text,
                        )
                      : null,
                  child: const Text('保存'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _status() {
    if (_dirty) return '未保存';
    if (!widget.config.isValid) return '未配置';
    return ref
        .watch(serverReachableProvider(widget.config.address))
        .when(
          loading: () => '测试中…',
          error: (_, __) => '未连接',
          data: (ok) => ok ? '已连接' : '未连接',
        );
  }
}
