import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/profile/second_page/data/providers/status_provider.dart';
import 'package:torrid/features/profile/second_page/data/widgets/network_config_widget.dart';
import 'package:torrid/features/profile/datas/___action_datas.dart';

class ProfileData extends ConsumerWidget {
  const ProfileData({super.key});

  // 网络请求时候的isLoading状态切换.
  Future<void> loadWithFunc(Future<void> func) async {
    // isLoading = true;
    await func;
    {
      // isLoading = false;
    }
  }

  // 显示确认对话框
  Future<void> showConfirmationDialog(
    BuildContext context,
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

  // 构建带样式的操作按钮
  Widget buildActionButton({
    required BuildContext context,
    required ActionInfo info,
  }) {
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
        onPressed: () =>
            showConfirmationDialog(context, info.label, info.action),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final List<ActionInfo> infos = actionInfos;

    return Container(
      child: ref.watch(loadingStateProvider)
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
                    // 网络地址输入框/状态栏
                    NetworkConfigWidget(),

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
                        buildActionButton(context: context, info: info),
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
                        buildActionButton(context: context, info: info),
                      ];
                    }),
                  ],
                ),
              ),
            ),
    );
  }
}
