import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/app/theme/theme_book.dart';
import 'package:torrid/features/todo/providers/notifier_provider.dart';
import 'package:torrid/features/todo/models/task_list.dart';
import 'package:torrid/features/todo/providers/status_provider.dart';

// 打开列表编辑弹窗（支持新建和重命名）
void openListEditSheet(BuildContext context, {TaskList? list}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    backgroundColor: AppTheme.surfaceContainer,
    builder: (context) => ListEditSheet(list: list),
  );
}

class ListEditSheet extends ConsumerStatefulWidget {
  final TaskList? list;

  const ListEditSheet({super.key, this.list});

  @override
  ConsumerState createState() => _ListEditSheetState();
}

class _ListEditSheetState extends ConsumerState<ListEditSheet> {
  late final TextEditingController _nameController;
  late int _currentOrder;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.list?.name ?? '');
    _currentOrder = widget.list?.order ?? 0;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _handleAction() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    if (widget.list != null) {
      if (widget.list!.order != _currentOrder) {
        await (ref
            .read(todoServiceProvider.notifier)
            .editList(widget.list!, name: name, newOrder: _currentOrder));
      }
    } else {
      ref.read(todoServiceProvider.notifier).addList(name);
    }
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.list != null;
    final allLists = ref.watch(taskListProvider);
    final modifiableStart = allLists.where((list) => list.isDefault).length;

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
            isEditing ? '编辑列表' : '新建列表',
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
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              filled: true,
              fillColor: AppTheme.surfaceContainer,
            ),
            style: theme.textTheme.titleMedium,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 24),

          // 顺序调整控件（仅编辑状态显示）
          if (isEditing && !widget.list!.isDefault) ...[
            const SizedBox(height: 16),
            Text('列表顺序', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_upward_rounded),
                  onPressed: _currentOrder > 0
                      ? () => setState(() => _currentOrder--)
                      : null,
                ),
                Expanded(
                  child: Slider(
                    value: _currentOrder.toDouble(),
                    min: modifiableStart.toDouble(),
                    max: (allLists.length - 1).toDouble(),
                    divisions: allLists.length - modifiableStart - 1,
                    label: '第${_currentOrder + 1}位',
                    onChanged: (value) {
                      setState(() => _currentOrder = value.toInt());
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_downward_rounded),
                  onPressed: _currentOrder < allLists.length - 1
                      ? () => setState(() => _currentOrder++)
                      : null,
                ),
              ],
            ),
          ],

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
