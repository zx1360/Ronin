import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:torrid/features/todo/providers/content_provider.dart';
import 'package:torrid/features/todo/widgets/task_content/collapsed_tasks.dart';
import 'package:torrid/features/todo/widgets/task_content/task_item.dart';

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
    final allTasks = List.of(list.tasks);
    final completedTasks = allTasks.where((task) => task.isDone).toList();
    final incompleteTasks = allTasks.where((task) => !task.isDone).toList();

    // 分别排序
    incompleteTasks.sort((a, b) {
      // 按优先级降序比较
      final priorityCompare = b.priority.index.compareTo(a.priority.index);
      if (priorityCompare != 0) {
        return priorityCompare;
      }

      return a.createAt.compareTo(b.createAt); // 开始时间时间降序
    });
    completedTasks.sort((a, b) {
      final aTime = a.doneAt ?? a.createAt;
      final bTime = b.doneAt ?? b.createAt;
      return bTime.compareTo(aTime);
    });
    return SlidableAutoCloseBehavior(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: incompleteTasks.length + (completedTasks.isNotEmpty ? 1 : 0),
        itemBuilder: (context, index) {
          // 渲染未完成任务
          if (index < incompleteTasks.length) {
            return TaskItem(
              task: incompleteTasks[index],
              listId: list.id,
            );
          }
          // 渲染已完成任务折叠组件（最后一项）
          return CollapsedTasks(
            completedTasks: completedTasks,
            listId: list.id,
          );
        },
      ),
    );
  }
}
