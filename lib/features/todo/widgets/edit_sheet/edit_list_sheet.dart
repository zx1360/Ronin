import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/app/theme_book.dart';
import 'package:torrid/features/todo/providers/notifier_provider.dart';
import 'package:torrid/features/todo/models/task_list.dart';

// 打开列表编辑弹窗（支持新建和重命名）
void openListEditSheet(BuildContext context, {TaskList? list}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    backgroundColor: AppTheme.surfaceContainer,
    builder: (context) => ListEditSheet(
      list: list,
    ),
  );
}

class ListEditSheet extends ConsumerStatefulWidget {
  final TaskList? list;

  const ListEditSheet({
    super.key,
    this.list,
  });

  @override
  ConsumerState createState() => _ListEditSheetState();
}

class _ListEditSheetState extends ConsumerState<ListEditSheet> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.list?.name ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _handleAction() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    if (widget.list != null) {
      ref.read(todoServiceProvider.notifier).rename(widget.list!, name);
    } else {
      ref.read(todoServiceProvider.notifier).addList(name);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.list != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题（新建/编辑）
          Text(
            isEditing ? '重命名列表' : '新建列表',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),

          // 列表名称输入框
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: '列表名称*',
              labelStyle: theme.textTheme.labelMedium,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              filled: true,
              fillColor: AppTheme.surfaceContainer,
            ),
            style: theme.textTheme.titleMedium,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _handleAction(),
          ),
          const SizedBox(height: 24),

          // 操作按钮（创建/确认）
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _handleAction,
              child: Text(isEditing ? '确认' : '创建'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}