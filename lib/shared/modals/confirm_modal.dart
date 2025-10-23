import 'package:flutter/material.dart';
import 'package:torrid/app/theme_book.dart';

/// 弹出确认框，点击确定后执行相关逻辑
Future<bool?> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String content,
  required Function confirmFunc,
}) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppTheme.surfaceWarm, // 复用新增的温暖米色背景
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.outline.withOpacity(0.3)),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.primary, // 标题色与原noteTitle一致
              fontWeight: FontWeight.bold,
            ),
      ),
      content: Text(
        content,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.onSurface, // 内容色与原noteText一致
            ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          style: Theme.of(context).textButtonTheme.style?.copyWith(
                foregroundColor: WidgetStateProperty.all(AppTheme.onSurfaceVariant),
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
          child: Text("取消", style: TextStyle(color: AppTheme.onSurfaceVariant)), // 取消按钮色复刻原#8B7355
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: Theme.of(context).textButtonTheme.style?.copyWith(
                foregroundColor: WidgetStateProperty.all(AppTheme.errorVivid),
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
          child: Text("确定", style: TextStyle(color: AppTheme.errorVivid)), // 确定按钮色复刻原#D32F2F
        ),
      ],
    ),
  );
  if (confirm == true) {
    await confirmFunc();
  }
  return confirm;
}