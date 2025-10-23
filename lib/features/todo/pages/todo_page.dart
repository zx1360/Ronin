import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/todo/providers/content_provider.dart';

import 'package:torrid/features/todo/widgets/content/task_list_widget.dart';
import 'package:torrid/features/todo/widgets/bar/side_drawer.dart';
import 'package:torrid/features/todo/widgets/edit_sheet/edit_task_sheet.dart';

class TodoPage extends ConsumerWidget {
  const TodoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentList = ref.watch(contentProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(currentList?.name ?? "任务列表"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              openTaskModal(context, initialListId: currentList!.id);
            },
          ),
        ],
      ),
      drawer: SideDrawer(),
      body: TaskListWidget(),
    );
  }
}
