// 单个任务项
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:torrid/app/theme_book.dart';
import 'package:torrid/features/todo/models/todo_task.dart';
import 'package:torrid/features/todo/pages/task_detail_page.dart';
import 'package:torrid/features/todo/providers/notifier_provider.dart';
import 'package:torrid/features/todo/widgets/edit_sheet/edit_task_sheet.dart';
import 'package:torrid/features/todo/widgets/non_content_widget/priority_indicator.dart';
import 'package:torrid/shared/modals/confirm_modal.dart';

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
              showConfirmDialog(
                context: context,
                title: "任务状态切换",
                content: '确认将任务: \n"${task.title}"\n切换为${value ? "完成" : "未完成"}状态吗?',
                confirmFunc: () {
                  ref
                      .read(todoServiceProvider.notifier)
                      .toggleTask(task, value);
                },
              );
            },
          ),
          title: Text(
            task.title,
            style: theme.textTheme.titleMedium?.copyWith(
              decoration: task.isDone ? TextDecoration.lineThrough : null,
              color: task.isDone ? theme.colorScheme.onSurfaceVariant : null,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (task.dueDate != null)
                Text(
                  DateFormat.yMd().format(task.dueDate!),
                  style: theme.textTheme.bodySmall,
                ),
              if (task.desc != null && task.desc!.isNotEmpty)
                Text(
                  task.desc!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
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