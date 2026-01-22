/// 列表编辑弹窗
/// 
/// 支持创建新列表和编辑现有列表
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/todo/providers/notifier_provider.dart';
import 'package:torrid/features/todo/models/task_list.dart';
import 'package:torrid/features/todo/providers/content_provider.dart';

/// 打开列表编辑弹窗
void openListEditSheet(BuildContext context, {TaskList? list}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
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
  late ListThemeColor _selectedColor;

  bool get _isEditing => widget.list != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.list?.name ?? '');
    _selectedColor = widget.list?.themeColor ?? ListThemeColor.blue;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final service = ref.read(todoServiceProvider.notifier);

    if (_isEditing) {
      await service.editList(
        widget.list!,
        name: name,
        themeColor: _selectedColor,
      );
    } else {
      final newList = await service.addList(name, themeColor: _selectedColor);
      // 切换到新创建的列表
      if (newList != null) {
        ref.read(currentViewNotifierProvider.notifier)
            .switchToCustomList(newList.id);
      }
    }

    if (mounted) {
      Navigator.pop(context);
      // 如果是从抽屉打开的，关闭抽屉
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: bottomPadding + 24,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 拖动指示器
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            
            const SizedBox(height: 16),

            // 标题
            Text(
              _isEditing ? '编辑列表' : '新建列表',
              style: theme.textTheme.titleLarge,
            ),
            
            const SizedBox(height: 24),

            // 列表名称输入框
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: '列表名称',
                hintText: '输入列表名称',
                prefixIcon: Icon(
                  Icons.list,
                  color: _selectedColor.color,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _selectedColor.color,
                    width: 2,
                  ),
                ),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _handleSave(),
            ),
            
            const SizedBox(height: 24),

            // 颜色选择
            Text(
              '选择颜色',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            
            const SizedBox(height: 12),
            
            // 颜色选择网格
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: ListThemeColor.values.map((color) {
                final isSelected = color == _selectedColor;
                return InkWell(
                  onTap: () => setState(() => _selectedColor = color),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(
                              color: theme.colorScheme.onSurface,
                              width: 3,
                            )
                          : null,
                    ),
                    child: isSelected
                        ? Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 20,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 24),

            // 操作按钮
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _nameController.text.trim().isNotEmpty
                        ? _handleSave
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: _selectedColor.color,
                    ),
                    child: Text(_isEditing ? '保存' : '创建'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
