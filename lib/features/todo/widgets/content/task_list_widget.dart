import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:torrid/features/todo/models/todo_task.dart';
import 'package:torrid/features/todo/providers/notifier_provider.dart';
import 'package:torrid/features/todo/widgets/edit_sheet/edit_task_sheet.dart';
import 'package:torrid/features/todo/widgets/indicators/priority_indicator.dart';

// 任务列表主体
class TaskListWidget extends ConsumerWidget {
  const TaskListWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final list = ref.watch(todoServiceProvider).currentList;

    if (list == null || list.tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text('还没有任务', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '点击"+"添加任务',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: list.tasks.length,
      itemBuilder: (context, index) => TaskItem(list.tasks[index], list.id),
      // _buildTaskItem(theme, tasks[index], ref, listId),
    );
  }
}

// 单个任务项
class TaskItem extends ConsumerWidget {
  final TodoTask task;
  final String listId;
  const TaskItem(this.task, this.listId, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Dismissible(
      key: Key(task.id),
      background: Container(
        color: theme.colorScheme.errorContainer,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Icon(Icons.delete, color: theme.colorScheme.error),
      ),
      onDismissed: (direction) async {
        // await ref.read(taskRepositoryProvider).deleteTask(task.id, listId);
        // ref.invalidate(currentListTasksProvider); // 刷新列表
      },
      child: Card(
        child: ListTile(
          leading: Checkbox(
            value: task.isDone,
            onChanged: (value) async {
              // await ref.read(taskRepositoryProvider).toggleTask(task.id);
              // ref.invalidate(currentListTasksProvider);
            },
          ),
          title: Text(
            task.title,
            style: theme.textTheme.titleMedium?.copyWith(
              decoration: task.isDone ? TextDecoration.lineThrough : null,
              color: task.isDone ? theme.colorScheme.onSurfaceVariant : null,
            ),
          ),
          subtitle: task.dueDate != null
              ? Text(
                  DateFormat.yMd().format(task.dueDate!),
                  style: theme.textTheme.bodySmall,
                )
              : null,
          trailing: PriorityIndicator(priority: task.priority),
          onTap: () => openTaskDetail(context, listId: listId, task: task),
        ),
      ),
    );
  }
}
