import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/profile/second_page/data/models/action_info.dart';

// 构建带样式的操作按钮
class ActionButton extends ConsumerWidget {
  final BuildContext context;
  final ActionInfo info;
  final bool disabled;
  
  const ActionButton({
    super.key,
    required this.context,
    required this.info,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: disabled ? 0.5 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: disabled ? Colors.grey[100] : Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          boxShadow: disabled ? null : [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: TextButton.icon(
          onPressed: disabled
              ? null
              : () async {
                  final result = await showConfirmationDialog(
                    context,
                    info.label,
                    info.action,
                  );
                  if (result) {
                    // 直接执行传输操作，不使用旧的loadWithFunc
                    // 因为新的传输服务有自己的状态管理
                    await info.action();
                  }
                },
          icon: Icon(
            info.icon,
            color: disabled
                ? Colors.grey
                : Theme.of(context).colorScheme.primary,
          ),
          label: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                info.label,
                style: TextStyle(
                  fontSize: 15,
                  color: disabled
                      ? Colors.grey
                      : (info.highlighted ? Colors.red : Colors.black87),
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
      ),
    );
  }
}

// 显示确认对话框
Future<bool> showConfirmationDialog(
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

  return result == true;
}
