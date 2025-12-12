// dialogs.dart 文件
import 'package:flutter/material.dart';
import 'package:torrid/app/theme/theme_book.dart';
import 'package:torrid/core/constants/app_border_radius.dart';
import 'package:torrid/core/constants/spacing.dart';
import 'package:torrid/core/modals/dialog_option.dart'; // 确保导入你的主题文件

/// 弹出一个带有多个选项按钮的模态对话框。
/// [options] 参数接收一个 DialogOption 对象的列表，用于动态生成按钮。
Future<DialogOption?> showOptionsDialog({
  required BuildContext context,
  required String title,
  required String content,
  required List<DialogOption> options,
}) async {
  return showDialog<DialogOption?>(
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
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppTheme.onSurface),
      ),
      actions: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: options.map((option) {
            return TextButton(
              onPressed: () => Navigator.pop<DialogOption>(context, option),
              style: Theme.of(context).textButtonTheme.style?.copyWith(
                foregroundColor: WidgetStateProperty.all(
                  option.textColor ?? AppTheme.onSurfaceVariant,
                ),
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                ),
              ),
              child: Text(
                option.text,
                style: TextStyle(
                  color: option.textColor ?? AppTheme.onSurfaceVariant,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    ),
  );
}
