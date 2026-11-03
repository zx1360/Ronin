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
        Row(
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
        const SizedBox(height: AppSpacing.md),
        Row(
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
        for (final (index, config) in state.configs.indexed)
          _ServerConfigTile(
            key: ValueKey(config.id),
            index: index,
            config: config,
            isActive: index == state.activeIndex,
            canRemove: state.configs.length > 1,
          ),
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
