import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:torrid/app/theme/theme_book.dart';
import 'package:torrid/features/todo/models/todo_task.dart';

/// TodoTask详情底部弹窗组件, 高度为设备高度85%, 内容可滚动.
class TaskDetailPage extends StatelessWidget {
  final TodoTask task;

  const TaskDetailPage({
    super.key,
    required this.task,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('yyyy-MM-dd HH:mm');
    final theme = AppTheme.bookTheme();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
        minWidth: double.infinity,
      ),
      color: AppTheme.surfaceContainer,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部拖动指示器
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 可滚动内容区
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题
                  Text(task.title, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 16),

                  // 描述（可选）
                  if (task.desc != null && task.desc!.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('任务描述', style: theme.textTheme.titleSmall),
                        const SizedBox(height: 4),
                        Text(task.desc!, style: theme.textTheme.bodyMedium, softWrap: true),
                        const SizedBox(height: 16),
                      ],
                    ),

                  // 状态
                  _buildDetailItem(
                    label: '任务状态',
                    value: task.isDone ? '已完成' : '未完成',
                    valueColor: task.isDone ? AppTheme.secondary : AppTheme.onSurface,
                    theme: theme,
                  ),
                  const SizedBox(height: 12),

                  // 完成时间（仅已完成任务且有完成时间时显示）
                  if (task.isDone && task.doneAt != null) ...[
                    _buildDetailItem(
                      label: '完成时间',
                      value: dateFormatter.format(task.doneAt!),
                      valueColor: AppTheme.secondary,
                      theme: theme,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 截止日期（可选）
                  if (task.dueDate != null) ...[
                    _buildDetailItem(
                      label: '截止日期',
                      value: dateFormatter.format(task.dueDate!),
                      theme: theme,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 提醒时间（可选）
                  if (task.reminder != null) ...[
                    _buildDetailItem(
                      label: '提醒时间',
                      value: dateFormatter.format(task.reminder!),
                      theme: theme,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 优先级
                  _buildDetailItem(
                    label: '优先级',
                    value: _getPriorityText(task.priority),
                    valueColor: _getPriorityColor(task.priority),
                    theme: theme,
                  ),
                  const SizedBox(height: 12),

                  // 创建时间
                  _buildDetailItem(
                    label: '创建时间',
                    value: dateFormatter.format(task.createAt),
                    theme: theme,
                  ),
                  const SizedBox(height: 24),

                  // 关闭按钮
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('关闭详情', style: theme.textTheme.labelLarge),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem({
    required String label,
    required String value,
    required ThemeData theme,
    Color? valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: valueColor ?? AppTheme.onSurface,
          ),
        ),
      ],
    );
  }

  String _getPriorityText(Priority priority) {
    switch (priority) {
      case Priority.low: return '低';
      case Priority.medium: return '中';
      case Priority.high: return '高';
      case Priority.intensive: return '紧急';
    }
  }

  Color _getPriorityColor(Priority priority) {
    switch (priority) {
      case Priority.low: return AppTheme.onSurfaceVariant;
      case Priority.medium: return AppTheme.primary;
      case Priority.high: return Colors.orange;
      case Priority.intensive: return AppTheme.errorVivid;
    }
  }
}