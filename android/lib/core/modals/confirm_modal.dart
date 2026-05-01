import 'package:flutter/material.dart';
import 'package:torrid/app/theme/theme_book.dart';
import 'package:torrid/core/constants/app_border_radius.dart';
import 'package:torrid/core/constants/spacing.dart';

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
      backgroundColor: AppTheme.surfaceWarm,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        side: BorderSide(color: AppTheme.outline.withAlpha(76)),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
      content: Text(
        content,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.onSurface,
            ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          style: Theme.of(context).textButtonTheme.style?.copyWith(
                foregroundColor: WidgetStateProperty.all(AppTheme.onSurfaceVariant),
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                ),
              ),
          child: Text("取消", style: TextStyle(color: AppTheme.onSurfaceVariant)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: Theme.of(context).textButtonTheme.style?.copyWith(
                foregroundColor: WidgetStateProperty.all(AppTheme.errorVivid),
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                ),
              ),
          child: Text("确定", style: TextStyle(color: AppTheme.errorVivid)),
        ),
      ],
    ),
  );
  if (confirm == true) {
    await confirmFunc();
  }
  return confirm;
}