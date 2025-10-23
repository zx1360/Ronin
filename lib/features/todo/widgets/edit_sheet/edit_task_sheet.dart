import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:torrid/features/todo/models/todo_task.dart';
import 'package:torrid/features/todo/providers/content_provider.dart';
import 'package:torrid/features/todo/providers/notifier_provider.dart';
import 'package:torrid/features/todo/providers/status_provider.dart';
import 'package:torrid/shared/utils/util.dart';

// 统一打开任务弹窗(新增/编辑)
void openTaskModal(
  BuildContext context, {
  required String initialListId,
  TodoTask? task,
}) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    isScrollControlled: true,
    builder: (context) =>
        TaskModalSheet(initialListId: initialListId, existingTask: task),
  );
}

// 任务弹窗组件
class TaskModalSheet extends ConsumerStatefulWidget {
  final String initialListId;
  final TodoTask? existingTask;

  const TaskModalSheet({
    super.key,
    required this.initialListId,
    this.existingTask,
  });

  @override
  ConsumerState createState() => _TaskModalSheetState();
}

class _TaskModalSheetState extends ConsumerState<TaskModalSheet> {
  // 任务相关信息
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  DateTime? _dueDate;
  DateTime? _reminder;
  late Priority _priority;
  RepeatCycle? _repeatCycle;
  late String _selectedListId;

  // 判断是否为编辑模式
  bool get _isEditing => widget.existingTask != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      // 编辑模式：初始化任务数据
      final task = widget.existingTask!;
      _titleController = TextEditingController(text: task.title);
      _descController = TextEditingController(text: task.desc);
      _dueDate = task.dueDate;
      _reminder = task.reminder;
      _priority = task.priority;
      _repeatCycle = task.repeatCycle;
      _selectedListId = widget.initialListId;
    } else {
      // 新增模式：初始化默认值
      _titleController = TextEditingController();
      _descController = TextEditingController();
      _priority = Priority.low;
      _selectedListId = widget.initialListId;
    }
  }

  // 统一保存逻辑（区分新增/编辑）
  Future<void> _saveTask() async {
    if (_titleController.text.isEmpty) return;

    final repository = ref.read(todoServiceProvider.notifier);

    if (_isEditing) {
      await repository.editTask(
        initialListId: widget.initialListId,
        selectedListId: _selectedListId,
        task: widget.existingTask!.copyWith(
          title: _titleController.text,
          desc: _descController.text,
          dueDate: _dueDate,
          reminder: _reminder,
          priority: _priority,
          repeatCycle: _repeatCycle,
        ),
      );
    } else {
      await repository.addTask(
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
    }
    ref
        .read(contentProvider.notifier)
        .switchList(ref.read(listWithIdProvider(_selectedListId)));

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final taskLists = ref.watch(taskListProvider);

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Padding(
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
              // 标题区分新增/编辑
              Text(
                _isEditing ? '编辑任务' : '新增任务',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              // 任务标题
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: '任务标题*',
                  hintText: '请输入任务名称',
                ),
                style: theme.textTheme.titleMedium,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              // 任务描述
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
              // 保存按钮（文字区分）
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveTask,
                  child: Text(_isEditing ? '保存' : '创建任务'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // 共用日期选择组件
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
