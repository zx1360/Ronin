import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torrid/features/profile/datas/action_datas.dart';

class ProfileData extends StatefulWidget {
  const ProfileData({super.key});

  @override
  State<ProfileData> createState() => _ProfileDataState();
}

class _ProfileDataState extends State<ProfileData> {
  final List<ActionInfo> infos = InfoDatas.infos;
  bool isLoading = false;
  final TextEditingController _ipController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadIpAddress();
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  // 加载保存的IP地址
  Future<void> _loadIpAddress() async {
    final prefs = await SharedPreferences.getInstance();
    final ipAddress = prefs.getString('PC_IP');

    setState(() {
      _ipController.text = ipAddress ?? '';
    });
  }

  // 保存IP地址
  Future<void> _saveIpAddress() async {
    final ipAddress = _ipController.text.trim();
    final prefs = await SharedPreferences.getInstance();

    if (ipAddress.isNotEmpty) {
      await prefs.setString('PC_IP', ipAddress);

      // 显示保存成功提示
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('IP地址已保存')));
      }
    }
  }

  Future<void> loadWithFunc(Future<void> func) async {
    setState(() {
      isLoading = true;
    });
    await func;
    setState(() {
      isLoading = false;
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

    return Scaffold(
      appBar: AppBar(title: const Text('数据同步'), elevation: 0),
      body: isLoading
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
                    // IP地址输入框
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
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _ipController,
                              decoration: const InputDecoration(
                                hintText: '输入...',
                                border: InputBorder.none,
                                hintStyle: TextStyle(color: Colors.grey),
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                              keyboardType: TextInputType.url,
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _saveIpAddress,
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
