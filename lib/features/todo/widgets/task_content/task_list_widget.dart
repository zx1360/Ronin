import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:torrid/features/todo/models/task_list.dart';
import 'package:torrid/features/todo/models/todo_task.dart';
import 'package:torrid/features/todo/providers/content_provider.dart';
import 'package:torrid/features/todo/providers/status_provider.dart';
import 'package:torrid/features/todo/widgets/task_content/collapsed_tasks.dart';
import 'package:torrid/features/todo/widgets/task_content/task_item.dart';

/// 任务列表主体组件
/// 
/// 根据当前视图类型（智能列表或自定义列表）显示对应的任务
class TaskListWidget extends ConsumerWidget {
  const TaskListWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentView = ref.watch(currentViewNotifierProvider);

    // 根据视图类型获取任务列表
    final (incompleteTasks, completedTasks) = _getTasksByView(ref, currentView);

    // 无任务时显示空状态
    if (incompleteTasks.isEmpty && completedTasks.isEmpty) {
      return _buildEmptyState(context, theme, currentView);
    }

    return SlidableAutoCloseBehavior(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: incompleteTasks.length + (completedTasks.isNotEmpty ? 1 : 0),
        itemBuilder: (context, index) {
          // 渲染未完成任务
          if (index < incompleteTasks.length) {
            return TaskItem(task: incompleteTasks[index]);
          }
          // 渲染已完成任务折叠组件
          return CollapsedTasks(completedTasks: completedTasks);
        },
      ),
    );
  }

  /// 根据视图类型获取对应的任务
  (List<TodoTask>, List<TodoTask>) _getTasksByView(
    WidgetRef ref,
    CurrentView view,
  ) {
    return switch (view) {
      SmartListView(:final type) => _getSmartListTasks(ref, type),
      CustomListView(:final listId) => _getCustomListTasks(ref, listId),
    };
  }

  /// 获取智能列表的任务
  (List<TodoTask>, List<TodoTask>) _getSmartListTasks(
    WidgetRef ref,
    SmartListType type,
  ) {
    final completedTasks = ref.watch(completedTasksProvider);
    
    return switch (type) {
      SmartListType.myDay => (
        ref.watch(myDayTasksProvider),
        completedTasks.where((t) => t.isInMyDayToday).toList(),
      ),
      SmartListType.important => (
        ref.watch(importantTasksProvider),
        completedTasks.where((t) => t.isImportant).toList(),
      ),
      SmartListType.planned => (
        ref.watch(plannedTasksProvider),
        completedTasks.where((t) => t.dueDate != null).toList(),
      ),
      SmartListType.all => (
        ref.watch(allIncompleteTasksProvider),
        completedTasks,
      ),
    };
  }

  /// 获取自定义列表的任务
  (List<TodoTask>, List<TodoTask>) _getCustomListTasks(
    WidgetRef ref,
    String listId,
  ) {
    return (
      ref.watch(incompleteTasksByListIdProvider(listId)),
      ref.watch(completedTasksByListIdProvider(listId)),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(
    BuildContext context,
    ThemeData theme,
    CurrentView view,
  ) {
    final (icon, title, subtitle) = switch (view) {
      SmartListView(:final type) => switch (type) {
        SmartListType.myDay => (
          Icons.wb_sunny_outlined,
          '专注于今天',
          '点击下方添加任务到"我的一天"',
        ),
        SmartListType.important => (
          Icons.star_outline,
          '没有重要任务',
          '标记重要的任务会显示在这里',
        ),
        SmartListType.planned => (
          Icons.calendar_today_outlined,
          '没有计划任务',
          '设置截止日期的任务会显示在这里',
        ),
        SmartListType.all => (
          Icons.inbox_outlined,
          '一切就绪',
          '添加任务开始你的待办事项',
        ),
      },
      CustomListView() => (
        Icons.check_circle_outline,
        '列表为空',
        '点击下方添加任务',
      ),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: theme.colorScheme.outline.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
