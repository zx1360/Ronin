import 'package:flutter/material.dart';
import 'package:torrid/features/todo/models/todo_task.dart';

// 优先级指示器
class PriorityIndicator extends StatelessWidget {
  final Priority priority;
  const PriorityIndicator({super.key, required this.priority});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color color;
    switch (priority) {
      case Priority.intensive:
        color = theme.colorScheme.error;
        break;
      case Priority.high:
        color = Colors.orangeAccent;
        break;
      case Priority.medium:
        color = Colors.yellow;
        break;
      case Priority.low:
        color = theme.colorScheme.outline;
    }
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
