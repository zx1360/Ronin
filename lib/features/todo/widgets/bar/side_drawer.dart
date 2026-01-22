import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import 'package:torrid/app/theme/theme_book.dart';
import 'package:torrid/features/todo/models/task_list.dart';
import 'package:torrid/features/todo/providers/content_provider.dart';
import 'package:torrid/features/todo/providers/notifier_provider.dart';
import 'package:torrid/features/todo/providers/status_provider.dart';
import 'package:torrid/features/todo/widgets/edit_sheet/edit_list_sheet.dart';
import 'package:torrid/core/modals/confirm_modal.dart';

/// 侧边栏抽屉
/// 
/// 参考 MS To-Do 设计，分为两部分：
/// 1. 智能列表（我的一天、重要、计划内、全部）
/// 2. 自定义列表
class SideDrawer extends ConsumerWidget {
  const SideDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final customLists = ref.watch(allListsProvider);
    final currentView = ref.watch(currentViewNotifierProvider);

    return Drawer(
      backgroundColor: theme.colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            // 头部用户区域
            _buildHeader(context, theme),
            
            const Divider(height: 1),
            
            // 可滚动内容
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // 智能列表部分
                  _buildSmartListsSection(context, ref, currentView, theme),
                  
                  const Divider(height: 1),
                  
                  // 自定义列表部分
                  _buildCustomListsSection(
                    context, 
                    ref, 
                    customLists, 
                    currentView,
                    theme,
                  ),
                ],
              ),
            ),
            
            // 底部新建列表按钮
            _buildNewListButton(context, theme),
          ],
        ),
      ),
    );
  }

  /// 构建头部
  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(
              Icons.person,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Todo',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '本地待办',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建智能列表部分
  Widget _buildSmartListsSection(
    BuildContext context,
    WidgetRef ref,
    CurrentView currentView,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 我的一天
        _SmartListItem(
          type: SmartListType.myDay,
          isSelected: currentView is SmartListView && 
              currentView.type == SmartListType.myDay,
          count: ref.watch(myDayTaskCountProvider),
          iconColor: const Color(0xFF2196F3),
        ),
        
        // 重要
        _SmartListItem(
          type: SmartListType.important,
          isSelected: currentView is SmartListView && 
              currentView.type == SmartListType.important,
          count: ref.watch(importantTaskCountProvider),
          iconColor: const Color(0xFFE91E63),
        ),
        
        // 计划内
        _SmartListItem(
          type: SmartListType.planned,
          isSelected: currentView is SmartListView && 
              currentView.type == SmartListType.planned,
          count: ref.watch(plannedTaskCountProvider),
          iconColor: const Color(0xFF4CAF50),
        ),
        
        // 全部
        _SmartListItem(
          type: SmartListType.all,
          isSelected: currentView is SmartListView && 
              currentView.type == SmartListType.all,
          count: ref.watch(allIncompleteTaskCountProvider),
          iconColor: theme.colorScheme.primary,
        ),
      ],
    );
  }

  /// 构建自定义列表部分
  Widget _buildCustomListsSection(
    BuildContext context,
    WidgetRef ref,
    List<TaskList> lists,
    CurrentView currentView,
    ThemeData theme,
  ) {
    return SlidableAutoCloseBehavior(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              '列表',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ...lists.map((list) => _CustomListItem(
            list: list,
            isSelected: currentView is CustomListView && 
                currentView.listId == list.id,
            taskCount: ref.watch(incompleteTaskCountProvider(list.id)),
          )),
        ],
      ),
    );
  }

  /// 构建新建列表按钮
  Widget _buildNewListButton(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: InkWell(
        onTap: () => openListEditSheet(context),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text('新建列表', style: TextStyle(
                color: theme.colorScheme.primary,
              )),
            ],
          ),
        ),
      ),
    );
  }
}

/// 智能列表项组件
class _SmartListItem extends ConsumerWidget {
  final SmartListType type;
  final bool isSelected;
  final int count;
  final Color iconColor;

  const _SmartListItem({
    required this.type,
    required this.isSelected,
    required this.count,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    
    return ListTile(
      leading: Icon(
        isSelected ? type.selectedIcon : type.icon,
        color: iconColor,
      ),
      title: Text(
        type.name,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? iconColor : null,
        ),
      ),
      trailing: count > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected 
                    ? iconColor.withOpacity(0.1)
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                count.toString(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isSelected ? iconColor : null,
                ),
              ),
            )
          : null,
      selected: isSelected,
      selectedTileColor: iconColor.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      onTap: () {
        ref.read(currentViewNotifierProvider.notifier).switchToSmartList(type);
        Navigator.pop(context);
      },
    );
  }
}

/// 自定义列表项组件
class _CustomListItem extends ConsumerWidget {
  final TaskList list;
  final bool isSelected;
  final int taskCount;

  const _CustomListItem({
    required this.list,
    required this.isSelected,
    required this.taskCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final listColor = list.themeColor.color;

    return Slidable(
      key: Key(list.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: list.isDefault ? 0.2 : 0.4,
        children: [
          // 编辑按钮
          SlidableAction(
            onPressed: (context) => openListEditSheet(context, list: list),
            icon: Icons.edit,
            foregroundColor: AppTheme.secondary,
            borderRadius: list.isDefault 
                ? BorderRadius.circular(12)
                : const BorderRadius.horizontal(left: Radius.circular(12)),
            padding: EdgeInsets.zero,
          ),
          // 删除按钮（默认列表不显示）
          if (!list.isDefault)
            SlidableAction(
              onPressed: (context) async {
                await showConfirmDialog(
                  context: context,
                  title: "确认删除",
                  content: "将删除列表「${list.name}」及其所有任务",
                  confirmFunc: () {
                    ref.read(todoServiceProvider.notifier).removeList(list);
                    // 如果删除的是当前选中的列表，切换到默认视图
                    final currentView = ref.read(currentViewNotifierProvider);
                    if (currentView is CustomListView && 
                        currentView.listId == list.id) {
                      ref.read(currentViewNotifierProvider.notifier)
                          .switchToDefault();
                    }
                  },
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
      child: ListTile(
        leading: Icon(
          list.icon,
          color: isSelected ? listColor : theme.colorScheme.onSurfaceVariant,
        ),
        title: Text(
          list.name,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? listColor : null,
          ),
        ),
        trailing: taskCount > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? listColor.withOpacity(0.1)
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  taskCount.toString(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isSelected ? listColor : null,
                  ),
                ),
              )
            : null,
        selected: isSelected,
        selectedTileColor: listColor.withOpacity(0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        onTap: () {
          ref.read(currentViewNotifierProvider.notifier)
              .switchToCustomList(list.id);
          Navigator.pop(context);
        },
      ),
    );
  }
}
