/// 已完成任务折叠组件
/// 
/// 默认折叠，点击展开/收起
library;
import 'package:flutter/material.dart';
import 'package:torrid/features/todo/models/todo_task.dart';
import 'package:torrid/features/todo/widgets/task_content/task_item.dart';

class CollapsedTasks extends StatefulWidget {
  final List<TodoTask> completedTasks;

  const CollapsedTasks({
    super.key,
    required this.completedTasks,
  });

  @override
  State<CollapsedTasks> createState() => _CollapsedTasksState();
}

class _CollapsedTasksState extends State<CollapsedTasks> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final taskCount = widget.completedTasks.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 折叠/展开触发栏
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '已完成',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      taskCount.toString(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 展开状态下显示已完成任务列表
        if (_isExpanded)
          ...widget.completedTasks.map(
            (task) => Opacity(
              opacity: 0.6,
              child: TaskItem(task: task),
            ),
          ),
      ],
    );
  }
}
