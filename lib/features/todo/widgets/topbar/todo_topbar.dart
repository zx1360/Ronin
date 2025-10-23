import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/todo/providers/notifier_provider.dart';
import 'package:torrid/features/todo/widgets/edit_sheet/add_task_sheet.dart';

class TodoTopbar extends ConsumerStatefulWidget implements PreferredSizeWidget {
  const TodoTopbar({super.key});

  @override
  ConsumerState<TodoTopbar> createState() => _TodoTopbarState();
  
  @override
  Size get preferredSize => const Size.fromHeight(112);
}

class _TodoTopbarState extends ConsumerState<TodoTopbar> {
  final searchController = TextEditingController();
  final searchFocusNode = FocusNode();
  
  @override
  Widget build(BuildContext context) {
    final currentList = ref.watch(todoServiceProvider).currentList;
    return AppBar(
      title: Text(currentList?.name??"任务列表"),
      actions: [
        IconButton(icon: const Icon(Icons.add), onPressed: () {
          openAddTask(context, initialListId: currentList!.id);
        }),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            focusNode: searchFocusNode,
            controller: searchController,
            decoration: InputDecoration(
              hintText: '搜索任务...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => searchController.clear(),
                    )
                  : null,
            ),
            onTapOutside: (event) => searchFocusNode.unfocus(),
          ),
        ),
      ),
    );
  }
}
