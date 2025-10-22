import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/todo/providers/notifier_provider.dart';

// 打开列表编辑弹窗
void openListEditSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => ListEditSheet(),
  );
}

class ListEditSheet extends ConsumerStatefulWidget {
  const ListEditSheet({super.key});

  @override
  ConsumerState createState() => _ListEditSheetState();
}

class _ListEditSheetState extends ConsumerState<ListEditSheet> {
  final _nameController = TextEditingController();

  void _createList() {
    if (_nameController.text.isEmpty) return;
    ref.read(todoServiceProvider.notifier).addList(_nameController.text);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('新建列表', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: '列表名称*'),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _createList,
              child: const Text('创建'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
