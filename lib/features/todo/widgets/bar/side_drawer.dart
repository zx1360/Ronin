import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import 'package:torrid/app/theme_book.dart';
import 'package:torrid/features/todo/models/task_list.dart';
import 'package:torrid/features/todo/providers/content_provider.dart';
import 'package:torrid/features/todo/providers/notifier_provider.dart';
import 'package:torrid/features/todo/providers/status_provider.dart';
import 'package:torrid/features/todo/widgets/edit_sheet/edit_list_sheet.dart';
import 'package:torrid/shared/modals/confirm_modal.dart';

// 左侧抽屉
class SideDrawer extends ConsumerWidget {
  const SideDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final taskLists = ref.watch(taskListProvider).skip(3).toList();

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: theme.colorScheme.primary),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                '任务列表',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ),
          ),
          Expanded(
            child: SlidableAutoCloseBehavior(
              child: ListView.builder(
                itemCount: taskLists.length,
                itemBuilder: (context, index) => ListItem(taskLists[index]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('新建列表'),
              onPressed: () => openListEditSheet(context),
            ),
          ),
        ],
      ),
    );
  }
}

// 抽屉中的列表项
class ListItem extends ConsumerWidget {
  final TaskList list;
  const ListItem(this.list, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedList = ref.watch(contentProvider);

    return list.isDefault
        ? ListTile(
            leading: Icon(Icons.star_border_purple500_outlined),
            title: Text(list.name),
            trailing: Text(
              list.tasks.length.toString(),
              style: theme.textTheme.bodySmall,
            ),
            selected: selectedList?.id == list.id,
            selectedColor: theme.colorScheme.primary,
            onTap: () {
              if (selectedList?.id != list.id) {
                ref.read(contentProvider.notifier).switchList(list);
                Navigator.pop(context);
              }
            },
          )
        : Slidable(
            key: Key(list.id),
            // 右划内容
            endActionPane: ActionPane(
              motion: const DrawerMotion(),
              extentRatio: 0.35,
              children: [
                SlidableAction(
                  onPressed: (context) =>
                      openListEditSheet(context, list: list),
                  icon: Icons.edit,
                  foregroundColor: AppTheme.secondary,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(12),
                  ),
                  padding: EdgeInsets.zero,
                ),
                SlidableAction(
                  onPressed: (context) async {
                    await showConfirmDialog(
                      context: context,
                      title: "确认删除",
                      content: "将删除列表'${list.name}'",
                      confirmFunc: () {
                        ref.read(todoServiceProvider.notifier).removeList(list);
                      },
                    );
                    if(list.id==selectedList?.id){
                      ref.read(contentProvider.notifier).initDefault();
                    }
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
            // 列表内容
            child: ListTile(
              leading: Icon(Icons.toc_rounded),
              title: Text(list.name),
              trailing: Text(
                list.tasks.length.toString(),
                style: theme.textTheme.bodySmall,
              ),
              selected: selectedList?.id == list.id,
              selectedColor: theme.colorScheme.primary,
              onTap: () {
                if (selectedList?.id != list.id) {
                  ref.read(contentProvider.notifier).switchList(list);
                  Navigator.pop(context);
                }
              },
            ),
          );
  }
}
