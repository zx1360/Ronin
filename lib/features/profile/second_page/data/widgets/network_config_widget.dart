/// 网络配置组件
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

/// 网络配置组件
///
/// 用于配置和测试与PC服务器的连接。
class NetworkConfigWidget extends StatefulWidget {
  final String initialHost;
  final String initialPort;
  final String apiKey;
  final bool canRemove;
  final bool isActive;
  final VoidCallback? onRemove;
  final VoidCallback? onActivate;
  final Future<void> Function(String host, String port) onSave;

  const NetworkConfigWidget({
    super.key,
    required this.initialHost,
    required this.initialPort,
    required this.apiKey,
    required this.onSave,
    this.canRemove = false,
    this.isActive = false,
    this.onRemove,
    this.onActivate,
  });

  @override
  State<NetworkConfigWidget> createState() => _NetworkConfigWidgetState();
}

class _NetworkConfigWidgetState extends State<NetworkConfigWidget> {
  final _ipController = TextEditingController();
  final _portController = TextEditingController();
  bool _isTesting = false;
  bool? _isConnected;

  @override
  void initState() {
    super.initState();
    _ipController.text = widget.initialHost;
    _portController.text = widget.initialPort;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _testConnection();
    });
  }

  Future<void> _testConnection() async {
    final host = _ipController.text.trim();
    final port = _portController.text.trim();
    if (host.isEmpty || port.isEmpty) {
      if (mounted) {
        setState(() {
          _isConnected = null;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isTesting = true;
      });
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
    final ip = _ipController.text.trim();
    final port = _portController.text.trim();

    await widget.onSave(ip, port);
    await _testConnection();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('配置已保存')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = _isConnected == null
      ? Colors.amber
      : _isConnected!
        ? Colors.lightGreenAccent
        : Colors.redAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: widget.isActive ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: widget.isActive
            ? Border.all(color: Colors.green, width: 2)
            : null,
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              children: [
                TextField(
                  controller: _ipController,
                  decoration: const InputDecoration(
                    hintText: '请输入IP地址(IPV4)...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.grey),
                    contentPadding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  keyboardType: TextInputType.url,
                ),
                TextField(
                  controller: _portController,
                  decoration: const InputDecoration(
                    hintText: '请输入端口...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.grey),
                    contentPadding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          IntrinsicWidth(
            child: Column(
              children: [
                Row(
                  children: [
                    const Text("连接状态: "),
                    Icon(
                      Icons.circle,
                      color: iconColor,
                    ),
                    if (_isTesting) ...[
                      const SizedBox(width: 6),
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                ),
                ElevatedButton(
                  onPressed: _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text('保存'),
                ),
                if (!widget.isActive)
                  TextButton(
                    onPressed: widget.onActivate,
                    child: const Text('启用'),
                  ),
                if (widget.isActive)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('当前启用', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ),
                if (widget.canRemove)
                  TextButton(
                    onPressed: widget.onRemove,
                    child: const Text('删除'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
