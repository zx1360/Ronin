import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:torrid/features/todo/models/todo_task.dart';
import 'package:torrid/features/todo/providers/notifier_provider.dart';
import 'package:torrid/features/todo/providers/status_provider.dart';
import 'package:torrid/shared/utils/util.dart';

// 打开新增任务弹窗
void openAddTask(
  BuildContext context, {
  required String initialListId, // 初始所属列表ID
}) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    isScrollControlled: true,
    builder: (context) => AddTaskSheet(initialListId: initialListId),
  );
}

// 新增任务组件
class AddTaskSheet extends ConsumerStatefulWidget {
  final String initialListId;

  const AddTaskSheet({super.key, required this.initialListId});

  @override
  ConsumerState createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends ConsumerState<AddTaskSheet> {
  // 新增任务的信息
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  DateTime? _dueDate;
  DateTime? _reminder;
  Priority _priority = Priority.low;
  RepeatCycle? _repeatCycle;
  late String _selectedListId;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descController = TextEditingController();
    _selectedListId = widget.initialListId;
  }

  // 保存新增任务
  Future<void> _saveNewTask() async {
    if (_titleController.text.isEmpty) return;

    await ref
        .read(todoServiceProvider.notifier)
        .addTask(
          _selectedListId,
          TodoTask(
            id: generateId(),
            title: _titleController.text,
            desc: _descController.text,
            isDone: false,
            dueDate: _dueDate,
            reminder: _reminder,
            priority: _priority,
            repeatCycle: _repeatCycle,
          ),
        );

    // 刷新任务列表数据
    ref
        .read(todoServiceProvider.notifier)
        .switchList(ref.read(listWithIdProvider(_selectedListId)));
    if (mounted) {
      Navigator.pop(context); // 关闭弹窗
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final taskLists = ref.watch(taskListProvider); // 获取所有列表

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom, // 适配键盘高度
          left: 16,
          right: 16,
          top: 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题：明确区分是“新增任务”
              Text('新增任务', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 16),
              // 任务标题（必填）
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: '任务标题*',
                  hintText: '请输入任务名称',
                ),
                style: theme.textTheme.titleMedium,
                textInputAction: TextInputAction.next, // 下一步
              ),
              const SizedBox(height: 16),
              // 任务描述（可选）
              TextField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: '任务描述',
                  hintText: '请输入任务详情（可选）',
                ),
                maxLines: 3,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              // 截止日期选择
              _buildDatePicker(
                theme,
                '截止日期',
                _dueDate,
                (date) => setState(() => _dueDate = date),
              ),
              // 提醒时间选择
              _buildDatePicker(
                theme,
                '提醒时间',
                _reminder,
                (date) => setState(() => _reminder = date),
              ),
              // 优先级选择（默认低）
              DropdownButtonFormField<Priority>(
                value: _priority,
                decoration: const InputDecoration(labelText: '优先级'),
                items: Priority.values
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(e.toString().split('.').last),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _priority = value!),
              ),
              // 重复周期选择（默认不重复）
              DropdownButtonFormField<RepeatCycle?>(
                value: _repeatCycle,
                decoration: const InputDecoration(labelText: '重复周期'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('不重复')),
                  ...RepeatCycle.values
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(e.toString().split('.').last),
                        ),
                      )
                      .toList(),
                ],
                onChanged: (value) => setState(() => _repeatCycle = value),
              ),
              // 所属列表选择（默认选中传入的列表）
              DropdownButtonFormField<String>(
                value: _selectedListId,
                decoration: const InputDecoration(labelText: '所属列表'),
                items: taskLists
                    .map(
                      (list) => DropdownMenuItem(
                        value: list.id,
                        child: Text(list.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _selectedListId = value!),
              ),
              const SizedBox(height: 24),
              // 保存按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveNewTask,
                  child: const Text('创建任务'), // 按钮文字区分于“保存”
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // 复用日期选择组件（与修改任务保持一致）
  Widget _buildDatePicker(
    ThemeData theme,
    String label,
    DateTime? date,
    Function(DateTime) onSelected,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: date ?? DateTime.now(),
            firstDate: DateTime.now(),
            lastDate: DateTime(2100),
          );
          if (picked != null) onSelected(picked);
          FocusManager.instance.primaryFocus?.unfocus();
        },
        child: InputDecorator(
          decoration: InputDecoration(labelText: label),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                date != null ? DateFormat.yMd().format(date) : '未设置',
                style: theme.textTheme.bodyMedium,
              ),
              const Icon(Icons.calendar_month),
            ],
          ),
        ),
      ),
    );
  }
}
