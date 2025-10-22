import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:torrid/features/todo/models/todo_task.dart';
import 'package:torrid/features/todo/providers/notifier_provider.dart';
import 'package:torrid/features/todo/providers/status_provider.dart';

// 打开任务详情弹窗
void openTaskDetail(
  BuildContext context, {
  required String listId,
  required TodoTask task,
}) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    isScrollControlled: true,
    builder: (context) => TaskDetailSheet(task: task, initialListId: listId),
  );
}

// 任务详情组件
class TaskDetailSheet extends ConsumerStatefulWidget {
  final TodoTask task;
  final String initialListId;

  const TaskDetailSheet({
    super.key,
    required this.task,
    required this.initialListId,
  });

  @override
  ConsumerState createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends ConsumerState<TaskDetailSheet> {
  // task的信息.
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
    final task = widget.task;
    _titleController = TextEditingController(text: task.title);
    _descController = TextEditingController(text: task.desc);
    _dueDate = task.dueDate;
    _reminder = task.reminder;
    _priority = task.priority;
    _repeatCycle = task.repeatCycle;
    _selectedListId = ref
        .read(taskListProvider)
        .firstWhere((l) => l.tasks.contains(task))
        .id;
  }

  Future<void> _saveTask() async {
    if (_titleController.text.isEmpty) return;

    final repository = ref.read(todoServiceProvider.notifier);
    // 更改任务信息
    await repository.editTask(
      initialListId: widget.initialListId,
      selectedListId: _selectedListId,
      task: widget.task.copyWith(
        title: _titleController.text,
        desc: _descController.text,
        dueDate: _dueDate,
        reminder: _reminder,
        priority: _priority,
        repeatCycle: _repeatCycle,
      ),
    );

    ref.invalidate(taskListProvider);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final taskLists = ref.watch(taskListProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '编辑任务',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: '任务标题*'),
              style: theme.textTheme.titleMedium,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(labelText: '任务描述'),
              maxLines: 3,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            // 截止日期
            _buildDatePicker(
              theme,
              '截止日期',
              _dueDate,
              (date) => setState(() => _dueDate = date),
            ),
            // 提醒时间
            _buildDatePicker(
              theme,
              '提醒时间',
              _reminder,
              (date) => setState(() => _reminder = date),
            ),
            // 优先级
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
            // 重复周期
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
            // 所属列表
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
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveTask,
                child: const Text('保存'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // 日期选择组件
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
