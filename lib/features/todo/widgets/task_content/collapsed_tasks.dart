// 已完成任务折叠组件
import 'package:flutter/material.dart';
import 'package:torrid/features/todo/models/todo_task.dart';
import 'package:torrid/features/todo/widgets/task_content/task_item.dart';

/// 默认折叠，点击展开/收起，样式匹配主题风格
class CollapsedTasks extends StatefulWidget {
  final List<TodoTask> completedTasks;
  final String listId;

  const CollapsedTasks({
    super.key,
    required this.completedTasks,
    required this.listId,
  });

  @override
  State<CollapsedTasks> createState() =>
      _CollapsedTasksState();
}

class _CollapsedTasksState
    extends State<CollapsedTasks> {
  // 控制折叠状态
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final taskCount = widget.completedTasks.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 折叠/展开触发栏
        Card(
          color: theme.colorScheme.surfaceContainer,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            leading: Icon(
              _isExpanded ? Icons.expand_less : Icons.expand_more,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            title: Text(
              '已完成任务 ($taskCount)',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: Text(
              _isExpanded ? '收起' : '展开',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ),

        // 展开状态下显示已完成任务列表
        if (_isExpanded)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: widget.completedTasks
                  .map((task) => Opacity(
                        // 已完成任务添加透明效果，视觉上与未完成任务区分
                        opacity: 0.7,
                        child: TaskItem(
                          task: task,
                          listId: widget.listId,
                        ),
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }
}
