import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/todo/models/task_list.dart';
import 'package:torrid/features/todo/providers/content_notifier.dart';
import 'package:torrid/features/todo/providers/status_provider.dart';
import 'package:torrid/features/todo/widgets/edit_sheet/edit_list_sheet.dart';

// 左侧抽屉
class SideDrawer extends ConsumerWidget {
  const SideDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final taskLists = ref.watch(taskListProvider);

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
            child: ListView.builder(
              itemCount: taskLists.length,
              itemBuilder: (context, index) => ListItem(taskLists[index]),
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
    final selectedList = ref.watch(contentServiceProvider);

    return ListTile(
      title: Text(list.name),
      trailing: Text(
        list.tasks.length.toString(),
        style: theme.textTheme.bodySmall,
      ),
      selected: selectedList?.id == list.id,
      selectedColor: theme.colorScheme.primary,
      onTap: () {
        if (selectedList?.id == list.id) {
          ref.read(contentServiceProvider.notifier).switchList(list: list);
          Navigator.pop(context);
        }
      },
    );
  }
}
