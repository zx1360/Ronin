import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:torrid/app/theme_book.dart';
import 'package:torrid/features/todo/models/todo_task.dart';
import 'package:torrid/features/todo/pages/task_detail_page.dart';
import 'package:torrid/features/todo/providers/content_provider.dart';
import 'package:torrid/features/todo/providers/notifier_provider.dart';
import 'package:torrid/features/todo/widgets/edit_sheet/edit_task_sheet.dart';
import 'package:torrid/features/todo/widgets/content/priority_indicator.dart';
import 'package:torrid/shared/modals/confirm_modal.dart';

// 任务列表主体
class TaskListWidget extends ConsumerWidget {
  const TaskListWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final list = ref.watch(contentProvider);

    // 无列表信息或无任务信息时显示.
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

    // 有任务信息时显示
    final tasks = List.of(list.tasks);
    tasks.sort((a, b) {
      // 1. 先按优先级降序比较
      final priorityCompare = b.priority.index.compareTo(a.priority.index);
      if (priorityCompare != 0) {
        return priorityCompare;
      }

      return b.createAt.compareTo(a.createAt); // 正常时间降序
    });
    return SlidableAutoCloseBehavior(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: tasks.length,
        itemBuilder: (context, index) =>
            TaskItem(task: tasks[index], listId: list.id),
      ),
    );
  }
}

// 单个任务项
class TaskItem extends ConsumerWidget {
  final TodoTask task;
  final String listId;
  const TaskItem({required this.task, required this.listId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Slidable(
      key: Key(task.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.35,
        children: [
          SlidableAction(
            onPressed: (context) =>
                openTaskModal(context, initialListId: listId, task: task),
            icon: Icons.edit,
            foregroundColor: AppTheme.secondary,
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(12),
            ),
            padding: EdgeInsets.zero,
          ),
          SlidableAction(
            onPressed: (context) {
              showConfirmDialog(
                context: context,
                title: "确认删除?",
                content: "将删除任务'${task.title}'",
                confirmFunc: () => ref
                    .read(todoServiceProvider.notifier)
                    .removeTask(listId, task),
              );
            },
            icon: Icons.delete,
            foregroundColor: AppTheme.error,
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(12),
            ),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
      // task简要信息.
      child: Card(
        child: ListTile(
          // 勾选框, 完成情况.
          leading: Checkbox(
            value: task.isDone,
            onChanged: (value) async {
              if (value == null) return;
              await ref
                  .read(todoServiceProvider.notifier)
                  .toggleTask(task, value);
              ref.invalidate(todoServiceProvider);
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
          // 重要度颜色指示.
          trailing: PriorityIndicator(priority: task.priority),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => TaskDetailPage(task: task)),
          ),
        ),
      ),
    );
  }
}
