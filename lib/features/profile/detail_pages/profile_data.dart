import 'package:flutter/material.dart';
import 'package:torrid/core/services/debug/logging_service.dart';
import 'package:torrid/core/services/network/apiclient_handler.dart';
import 'package:torrid/core/services/storage/prefs_service.dart';
import 'package:torrid/features/profile/datas/action_datas.dart';

class ProfileData extends StatefulWidget {
  const ProfileData({super.key});

  @override
  State<ProfileData> createState() => _ProfileDataState();
}

class _ProfileDataState extends State<ProfileData> {
  final List<ActionInfo> infos = InfoDatas.infos;

  bool isLoading = false;
  bool hasConnected = false;

  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAddress();
    _testRequest();
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  // 网络请求测试方法.
  Future<void> _testRequest() async {
    bool hasConnected_ = false;
    try {
      final resp = await ApiclientHandler.fetch(path: "/util/test");
      if (resp!.statusCode == 200) {
        hasConnected_ = true;
      }
    } catch (e) {
      AppLogger().info("_testRequest: 当前地址无web服务连接.");
    }
    if (hasConnected_ != hasConnected) {
      setState(() {
        hasConnected = hasConnected_;
      });
    }
  }

  // 加载保存的IP地址
  Future<void> _loadAddress() async {
    final prefs = PrefsService().prefs;
    final ip = prefs.getString('PC_IP');
    final port = prefs.getString("PC_PORT");

    setState(() {
      _ipController.text = ip ?? '';
      _portController.text = port ?? '';
    });
  }

  // 保存IP地址
  Future<void> _saveAddress() async {
    final ip = _ipController.text.trim();
    final port = _portController.text.trim();
    final prefs = PrefsService().prefs;

    await prefs.setString('PC_IP', ip);
    await prefs.setString('PC_PORT', port);
    _testRequest();
    // 显示保存成功提示
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('地址已保存.')));
    }
  }

  // 网络请求时候的isLoading状态切换.
  Future<void> loadWithFunc(Future<void> func) async {
    setState(() {
      isLoading = true;
    });
    await func;
    setState(() {
      if (mounted) {
        isLoading = false;
      }
    });
  }

  // 显示确认对话框
  Future<void> showConfirmationDialog(
    String actionText,
    Future<void> Function() action,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认操作'),
        content: Text('确定$actionText吗'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (result == true) {
      await loadWithFunc(action());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      child: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text("稍等...", style: TextStyle(fontSize: 16)),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
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
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                  ),
                                  keyboardType: TextInputType.url,
                                ),
                                TextField(
                                  controller: _portController,
                                  decoration: const InputDecoration(
                                    hintText: '请输入端口...',
                                    border: InputBorder.none,
                                    hintStyle: TextStyle(color: Colors.grey),
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
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
                                      color: hasConnected
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
                    ),

                    // 同步相关操作
                    Text(
                      "同步到本地:",
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    // 特殊的map(): expand, 其中每一元素返回零或多个元素的集合(之后再扁平合并)
                    ...infos.take((infos.length / 2).ceil()).expand((info) {
                      return [
                        const SizedBox(height: 8),
                        _buildActionButton(info: info),
                      ];
                    }),

                    const SizedBox(height: 24),

                    // 更新相关操作
                    Text(
                      "更新到外部:",
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    ...infos.skip((infos.length / 2).ceil()).expand((info) {
                      return [
                        const SizedBox(height: 8),
                        _buildActionButton(info: info),
                      ];
                    }),
                  ],
                ),
              ),
            ),
    );
  }

  // 构建带样式的操作按钮
  Widget _buildActionButton({required ActionInfo info}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: TextButton.icon(
        onPressed: () => showConfirmationDialog(info.label, info.action),
        icon: Icon(info.icon, color: Theme.of(context).colorScheme.primary),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              info.label,
              style: TextStyle(
                fontSize: 15,
                color: info.highlighted ? Colors.red : Colors.black87,
              ),
            ),
          ),
        ),
        style: TextButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          minimumSize: const Size(double.infinity, 50),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }
}
