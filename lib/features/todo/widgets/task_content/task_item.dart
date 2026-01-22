/// 单个任务项组件
/// 
/// 参考 MS To-Do 设计：
/// - 左侧圆形勾选框
/// - 中间任务标题和元信息
/// - 右侧星标按钮
/// - 支持滑动编辑/删除
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:torrid/app/theme/theme_book.dart';
import 'package:torrid/features/todo/models/todo_task.dart';
import 'package:torrid/features/todo/providers/notifier_provider.dart';
import 'package:torrid/features/todo/providers/status_provider.dart';
import 'package:torrid/features/todo/widgets/edit_sheet/edit_task_sheet.dart';
import 'package:torrid/core/modals/confirm_modal.dart';

class TaskItem extends ConsumerWidget {
  final TodoTask task;

  const TaskItem({
    required this.task,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final list = ref.watch(listByIdProvider(task.listId));
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Slidable(
        key: Key(task.id),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.4,
          children: [
            // 编辑按钮
            SlidableAction(
              onPressed: (context) => openTaskSheet(
                context,
                task: task,
              ),
              icon: Icons.edit,
              foregroundColor: AppTheme.secondary,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(12),
              ),
              padding: EdgeInsets.zero,
            ),
            // 删除按钮
            SlidableAction(
              onPressed: (context) {
                showConfirmDialog(
                  context: context,
                  title: "确认删除?",
                  content: "将删除任务「${task.title}」",
                  confirmFunc: () => ref
                      .read(todoServiceProvider.notifier)
                      .removeTask(task),
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
        child: Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: theme.colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: InkWell(
            onTap: () => openTaskSheet(context, task: task),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                children: [
                  // 勾选框
                  _buildCheckbox(context, ref, theme),
                  
                  // 任务内容
                  Expanded(
                    child: _buildContent(context, theme, list?.name),
                  ),
                  
                  // 星标按钮
                  _buildStarButton(ref, theme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建勾选框
  Widget _buildCheckbox(BuildContext context, WidgetRef ref, ThemeData theme) {
    return Checkbox(
      value: task.isDone,
      shape: const CircleBorder(),
      activeColor: theme.colorScheme.primary,
      side: BorderSide(
        color: task.isImportant 
            ? const Color(0xFFE91E63) 
            : theme.colorScheme.outline,
        width: 2,
      ),
      onChanged: (value) {
        ref.read(todoServiceProvider.notifier).toggleTaskDone(task);
      },
    );
  }

  /// 构建任务内容
  Widget _buildContent(BuildContext context, ThemeData theme, String? listName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 标题
        Text(
          task.title,
          style: theme.textTheme.bodyLarge?.copyWith(
            decoration: task.isDone ? TextDecoration.lineThrough : null,
            color: task.isDone 
                ? theme.colorScheme.onSurfaceVariant 
                : theme.colorScheme.onSurface,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        
        // 元信息行
        if (_hasMetaInfo(listName))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _buildMetaInfo(theme, listName),
          ),
      ],
    );
  }

  /// 检查是否有元信息
  bool _hasMetaInfo(String? listName) {
    return task.isInMyDayToday ||
        task.dueDate != null ||
        task.steps.isNotEmpty ||
        task.note?.isNotEmpty == true ||
        listName != null;
  }

  /// 构建元信息行
  Widget _buildMetaInfo(ThemeData theme, String? listName) {
    final items = <Widget>[];
    final metaStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final iconSize = 14.0;

    // "我的一天"标记
    if (task.isInMyDayToday) {
      items.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wb_sunny_outlined, size: iconSize, 
              color: const Color(0xFF2196F3)),
          const SizedBox(width: 2),
          Text('我的一天', style: metaStyle?.copyWith(
            color: const Color(0xFF2196F3),
          )),
        ],
      ));
    }

    // 截止日期
    if (task.dueDate != null) {
      final isOverdue = task.isOverdue;
      final isDueToday = task.isDueToday;
      final dateColor = isOverdue 
          ? Colors.red 
          : (isDueToday ? Colors.orange : theme.colorScheme.onSurfaceVariant);
      
      String dateText;
      if (isDueToday) {
        dateText = '今天';
      } else if (isOverdue) {
        dateText = '已过期';
      } else {
        dateText = DateFormat('M月d日').format(task.dueDate!);
      }

      items.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today_outlined, size: iconSize, color: dateColor),
          const SizedBox(width: 2),
          Text(dateText, style: metaStyle?.copyWith(color: dateColor)),
        ],
      ));
    }

    // 步骤进度
    if (task.steps.isNotEmpty) {
      items.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: iconSize, 
              color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 2),
          Text(task.stepsProgressText, style: metaStyle),
        ],
      ));
    }

    // 备注指示
    if (task.note?.isNotEmpty == true) {
      items.add(Icon(Icons.notes, size: iconSize, 
          color: theme.colorScheme.onSurfaceVariant));
    }

    // 所属列表（在智能列表视图中显示）
    if (listName != null) {
      items.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.list, size: iconSize, 
              color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 2),
          Text(listName, style: metaStyle),
        ],
      ));
    }

    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: items,
    );
  }

  /// 构建星标按钮
  Widget _buildStarButton(WidgetRef ref, ThemeData theme) {
    return IconButton(
      icon: Icon(
        task.isImportant ? Icons.star : Icons.star_outline,
        color: task.isImportant 
            ? const Color(0xFFE91E63) 
            : theme.colorScheme.onSurfaceVariant,
      ),
      onPressed: () {
        ref.read(todoServiceProvider.notifier).toggleTaskImportant(task);
      },
    );
  }
}