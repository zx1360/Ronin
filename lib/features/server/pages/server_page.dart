import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:northstar/_server/myserver.dart';
import 'package:northstar/providers/northstar/status_provider.dart';

class ServerPage extends ConsumerStatefulWidget {
  const ServerPage({super.key});

  @override
  ConsumerState<ServerPage> createState() => _ServerPageState();
}

class _ServerPageState extends ConsumerState<ServerPage> {
  String _statusMessage = "Web服务尚未启动...";
  final _portController = TextEditingController(text: "4215");
  final List<String> _logMessages = [];
  MyServer? _server;

  // 切换服务器运行状态
  Future<void> _toggleServer() async {
    final serverNotifier = ref.read(appStatusProvider.notifier);
    if (serverNotifier.isServerRunning) {
      await serverNotifier.stopServer();
      _addLog("Web服务已停止.");
    } else {
      try {
        final port = int.tryParse(_portController.text) ?? 4215;
        await serverNotifier.startServer(port: port);
        _addLog("服务器启动.");
      } catch (e) {
        _addLog("启动失败: ${e.toString()}");
      }
    }
    setState(() {
      _statusMessage = serverNotifier.isServerRunning
          ? "服务器运行中: ${_server?.address}"
          : "Web服务尚未启动";
    });
  }

  // 添加日志消息
  void _addLog(String message) {
    final time = DateTime.now().toString();
    setState(() {
      _logMessages.insert(0, "[$time] $message");
      // 限制日志数量
      if (_logMessages.length > 100) {
        _logMessages.removeLast();
      }
    });
  }

  // 复制服务器地址到剪贴板
  void _copyServerAddress() {
    final server = ref.watch(appStatusProvider.select((p) => p.server));
    if (server.isRunning) {
      final address = "http://${server.address}";
      Clipboard.setData(ClipboardData(text: address));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("已复制地址: $address")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorTheme = Theme.of(context).colorScheme;
    _server ??= ref.watch(appStatusProvider.select((p) => p.server));

    // UI
    return Container(
      color: colorTheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 服务器控制区域
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _portController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "服务器端口",
                              hintText: "输入端口号(1-65535)",
                              border: OutlineInputBorder(),
                            ),
                            enabled: !_server!.isRunning,
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _toggleServer,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            backgroundColor: _server!.isRunning
                                ? colorTheme.onSecondary
                                : Theme.of(context).primaryColor,
                          ),
                          child: Text(
                            _server!.isRunning ? "停止服务器" : "启动服务器",
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.amber,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _statusMessage,
                          style: TextStyle(
                            fontSize: 16,
                            color: _server!.isRunning
                                ? Colors.green
                                : Colors.grey,
                          ),
                        ),
                        if (_server!.isRunning)
                          TextButton.icon(
                            onPressed: _copyServerAddress,
                            icon: const Icon(Icons.copy),
                            label: const Text("复制地址"),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 日志区域
            const Text(
              "服务器日志:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: _logMessages.isEmpty
                      ? const Center(child: Text("暂无日志信息"))
                      : ListView.builder(
                          itemCount: _logMessages.length,
                          itemBuilder: (context, index) => Text(
                            _logMessages[index],
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
