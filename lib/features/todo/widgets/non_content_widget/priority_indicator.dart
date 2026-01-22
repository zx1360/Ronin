import 'package:flutter/material.dart';
import 'package:torrid/features/todo/models/todo_task.dart';

/// 优先级指示器
/// 
/// 显示任务的重要性状态（星标/普通）
class PriorityIndicator extends StatelessWidget {
  final Priority priority;
  const PriorityIndicator({super.key, required this.priority});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isImportant = priority == Priority.important;
    
    return Icon(
      isImportant ? Icons.star : Icons.star_border,
      size: 16,
      color: isImportant 
          ? Colors.amber 
          : theme.colorScheme.outline,
    );
  }
}
