import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/profile/second_page/data/providers/data_notifier_provider.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

class NetworkConfigWidget extends ConsumerStatefulWidget {
  const NetworkConfigWidget({super.key});

  @override
  ConsumerState<NetworkConfigWidget> createState() =>
      _NetworkConfigWidgetState();
}

class _NetworkConfigWidgetState extends ConsumerState<NetworkConfigWidget> {
  final _ipController = TextEditingController();
  final _portController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ip = ref.watch(apiClientManagerProvider.notifier).ip;
      final port = ref.watch(apiClientManagerProvider.notifier).port;
      _ipController.text = ip;
      _portController.text = port;
      ref.read(dataServerProvider.notifier).testNetwork();
    });
  }

  // 保存IP地址
  Future<void> _saveAddress() async {
    final ip = _ipController.text.trim();
    final port = _portController.text.trim();

    ref.watch(apiClientManagerProvider.notifier).setAddress(ip, port);
    // TODO:👇
    ref.read(dataServerProvider.notifier).testNetwork();
    // 显示保存成功提示
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('地址已保存.')));
    }
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
                      color: ref.watch(dataServerProvider)['connected']
                          ? Colors.lightGreenAccent
                          : Colors.amber,
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: _saveAddress,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text('保存'),
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
