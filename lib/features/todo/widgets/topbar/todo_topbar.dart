import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/todo/providers/content_notifier.dart';

class TodoTopbar extends ConsumerStatefulWidget implements PreferredSizeWidget {
  const TodoTopbar({super.key});

  @override
  ConsumerState<TodoTopbar> createState() => _TodoTopbarState();
  
  @override
  // Size get preferredSize => throw UnimplementedError();
  Size get preferredSize => const Size.fromHeight(112);
}

class _TodoTopbarState extends ConsumerState<TodoTopbar> {
  final searchController = TextEditingController();
  
  @override
  Widget build(BuildContext context) {   
    return AppBar(
      title: Text(ref.watch(contentServiceProvider)?.name??"任务列表"), //TODO: list.name
      actions: [
        IconButton(
          icon: const Icon(Icons.filter_list),
          onPressed: () {}, // 筛选逻辑
        ),
        IconButton(icon: const Icon(Icons.add), onPressed: () {}),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
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
          ),
        ),
      ),
    );
  }
}
