import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/providers/server_connect/server_conn_provider.dart';

class NetworkConfigWidget extends ConsumerStatefulWidget {
  const NetworkConfigWidget({super.key});

  @override
  ConsumerState<NetworkConfigWidget> createState() =>
      _NetworkConfigWidgetState();
}

class _NetworkConfigWidgetState extends ConsumerState<NetworkConfigWidget> {
  // TODO: 之后有了NAS使用家里的公网ip+DDNS, 省去"IP_"这一中间人.
  final _ipController = TextEditingController();
  final _portController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 读取ip, port存的值并test网络.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final conf = ref.read(serverConnectorProvider);
      _ipController.text=conf['host_']!;
      _portController.text=conf['port_']!;
    });
    ref.read(serverConnectorProvider.notifier).test();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 地址输入区域
          Expanded(
            child: Column(
              children: [
                TextField(
                  readOnly: true,
                  controller: _ipController,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.grey),
                    contentPadding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  keyboardType: TextInputType.url,
                ),
                TextField(
                  readOnly: true,
                  controller: _portController,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.grey),
                    contentPadding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  keyboardType: TextInputType.url,
                ),
              ],
            ),
          ),
          IntrinsicWidth(
            child: Column(
              children: [
                Row(
                  children: [
                    Text("连接状态: "),
                    Icon(
                      Icons.circle,
                      color: ref.watch(serverConnectorProvider)['connected']
                          ? Colors.lightGreenAccent
                          : Colors.amber,
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: ref.read(serverConnectorProvider.notifier).test,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text('测试'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
