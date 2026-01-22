/// 任务编辑/详情底部弹窗
/// 
/// 参考 MS To-Do 设计，提供完整的任务编辑功能：
/// - 标题编辑
/// - 步骤/子任务管理
/// - 添加到我的一天
/// - 截止日期设置
/// - 提醒设置
/// - 重复设置
/// - 备注
/// - 所属列表选择
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:torrid/features/todo/models/task_list.dart';
import 'package:torrid/features/todo/models/todo_task.dart';
import 'package:torrid/features/todo/providers/notifier_provider.dart';
import 'package:torrid/features/todo/providers/status_provider.dart';
import 'package:torrid/core/utils/util.dart';

/// 打开任务编辑弹窗
void openTaskSheet(
  BuildContext context, {
  TodoTask? task,
  String? defaultListId,
  bool addToMyDay = false,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => TaskEditSheet(
      existingTask: task,
      defaultListId: defaultListId,
      addToMyDay: addToMyDay,
    ),
  );
}

/// 任务编辑弹窗组件
class TaskEditSheet extends ConsumerStatefulWidget {
  final TodoTask? existingTask;
  final String? defaultListId;
  final bool addToMyDay;

  const TaskEditSheet({
    super.key,
    this.existingTask,
    this.defaultListId,
    this.addToMyDay = false,
  });

  @override
  ConsumerState createState() => _TaskEditSheetState();
}

class _TaskEditSheetState extends ConsumerState<TaskEditSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  late final TextEditingController _stepController;
  
  late String _selectedListId;
  late bool _isMyDay;
  late bool _isImportant;
  DateTime? _dueDate;
  DateTime? _reminder;
  RepeatType _repeatType = RepeatType.none;
  late List<TodoStep> _steps;

  bool get _isEditing => widget.existingTask != null;

  @override
  void initState() {
    super.initState();
    _stepController = TextEditingController();
    
    if (_isEditing) {
      final task = widget.existingTask!;
      _titleController = TextEditingController(text: task.title);
      _noteController = TextEditingController(text: task.note ?? '');
      _selectedListId = task.listId;
      _isMyDay = task.isInMyDayToday;
      _isImportant = task.isImportant;
      _dueDate = task.dueDate;
      _reminder = task.reminder;
      _repeatType = task.repeatType;
      _steps = List.from(task.steps);
    } else {
      _titleController = TextEditingController();
      _noteController = TextEditingController();
      _selectedListId = widget.defaultListId ?? 
          ref.read(defaultTaskListProvider)?.id ?? '';
      _isMyDay = widget.addToMyDay;
      _isImportant = false;
      _steps = [];
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    _stepController.dispose();
    super.dispose();
  }

  /// 保存任务
  Future<void> _saveTask() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final service = ref.read(todoServiceProvider.notifier);
    final now = DateTime.now();

    if (_isEditing) {
      // 更新现有任务
      final updatedTask = widget.existingTask!.copyWith(
        title: title,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        clearNote: _noteController.text.trim().isEmpty,
        listId: _selectedListId,
        isMyDay: _isMyDay,
        myDayDate: _isMyDay ? now : null,
        clearMyDayDate: !_isMyDay,
        priority: _isImportant ? Priority.important : Priority.normal,
        dueDate: _dueDate,
        clearDueDate: _dueDate == null,
        reminder: _reminder,
        clearReminder: _reminder == null,
        repeatType: _repeatType,
        steps: _steps,
      );
      await service.updateTask(updatedTask);
    } else {
      // 创建新任务
      final newTask = TodoTask(
        id: generateId(),
        title: title,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        listId: _selectedListId,
        isMyDay: _isMyDay,
        myDayDate: _isMyDay ? now : null,
        priority: _isImportant ? Priority.important : Priority.normal,
        dueDate: _dueDate,
        reminder: _reminder,
        repeatType: _repeatType,
        steps: _steps,
      );
      await service.addTask(newTask);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  /// 添加步骤
  void _addStep() {
    final stepTitle = _stepController.text.trim();
    if (stepTitle.isEmpty) return;
    
    setState(() {
      _steps.add(TodoStep(
        id: generateId(),
        title: stepTitle,
      ));
      _stepController.clear();
    });
  }

  /// 切换步骤完成状态
  void _toggleStep(int index) {
    setState(() {
      _steps[index] = _steps[index].copyWith(isDone: !_steps[index].isDone);
    });
  }

  /// 删除步骤
  void _removeStep(int index) {
    setState(() {
      _steps.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖动指示器
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outline.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // 可滚动内容
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: bottomPadding + 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题输入框
                  _buildTitleInput(theme),
                  
                  const Divider(height: 1),
                  
                  // 步骤列表
                  _buildStepsSection(theme),
                  
                  const Divider(height: 1),
                  
                  // 添加到我的一天
                  _buildMyDayOption(theme),
                  
                  const Divider(height: 1),
                  
                  // 截止日期
                  _buildDueDateOption(theme),
                  
                  // 提醒
                  _buildReminderOption(theme),
                  
                  // 重复（仅当有截止日期时显示）
                  if (_dueDate != null)
                    _buildRepeatOption(theme),
                  
                  const Divider(height: 1),
                  
                  // 所属列表
                  _buildListSelector(theme),
                  
                  const Divider(height: 1),
                  
                  // 备注
                  _buildNoteInput(theme),
                  
                  const SizedBox(height: 16),
                  
                  // 保存按钮
                  _buildSaveButton(theme),
                  
                  // 删除按钮（编辑模式）
                  if (_isEditing)
                    _buildDeleteButton(theme),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建标题输入框
  Widget _buildTitleInput(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // 勾选框样式按钮
          IconButton(
            onPressed: () => setState(() => _isImportant = !_isImportant),
            icon: Icon(
              _isImportant ? Icons.star : Icons.star_outline,
              color: _isImportant 
                  ? const Color(0xFFE91E63) 
                  : theme.colorScheme.outline,
            ),
          ),
          // 标题输入
          Expanded(
            child: TextField(
              controller: _titleController,
              style: theme.textTheme.titleMedium,
              decoration: InputDecoration(
                hintText: '任务标题',
                border: InputBorder.none,
                hintStyle: TextStyle(
                  color: theme.colorScheme.outline,
                ),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _saveTask(),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建步骤部分
  Widget _buildStepsSection(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 已有步骤列表
        ..._steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          return ListTile(
            leading: Checkbox(
              value: step.isDone,
              shape: const CircleBorder(),
              onChanged: (_) => _toggleStep(index),
            ),
            title: Text(
              step.title,
              style: TextStyle(
                decoration: step.isDone ? TextDecoration.lineThrough : null,
                color: step.isDone 
                    ? theme.colorScheme.onSurfaceVariant 
                    : null,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => _removeStep(index),
            ),
            contentPadding: const EdgeInsets.only(left: 8, right: 0),
            dense: true,
          );
        }),
        
        // 添加步骤输入框
        ListTile(
          leading: Icon(
            Icons.add,
            color: theme.colorScheme.primary,
          ),
          title: TextField(
            controller: _stepController,
            decoration: InputDecoration(
              hintText: '添加步骤',
              border: InputBorder.none,
              hintStyle: TextStyle(
                color: theme.colorScheme.primary,
              ),
            ),
            style: TextStyle(color: theme.colorScheme.primary),
            onSubmitted: (_) => _addStep(),
          ),
          contentPadding: const EdgeInsets.only(left: 16),
          dense: true,
        ),
      ],
    );
  }

  /// 构建"我的一天"选项
  Widget _buildMyDayOption(ThemeData theme) {
    final isActive = _isMyDay;
    final color = isActive ? const Color(0xFF2196F3) : theme.colorScheme.onSurfaceVariant;
    
    return ListTile(
      leading: Icon(
        isActive ? Icons.wb_sunny : Icons.wb_sunny_outlined,
        color: color,
      ),
      title: Text(
        '添加到"我的一天"',
        style: TextStyle(color: color),
      ),
      trailing: isActive
          ? IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => setState(() => _isMyDay = false),
            )
          : null,
      onTap: () => setState(() => _isMyDay = !_isMyDay),
    );
  }

  /// 构建截止日期选项
  Widget _buildDueDateOption(ThemeData theme) {
    final hasDate = _dueDate != null;
    final color = hasDate 
        ? const Color(0xFF4CAF50) 
        : theme.colorScheme.onSurfaceVariant;
    
    String displayText = '添加截止日期';
    if (hasDate) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dueDay = DateTime(_dueDate!.year, _dueDate!.month, _dueDate!.day);
      
      if (dueDay == today) {
        displayText = '今天';
      } else if (dueDay == today.add(const Duration(days: 1))) {
        displayText = '明天';
      } else {
        displayText = DateFormat('M月d日').format(_dueDate!);
      }
    }

    return ListTile(
      leading: Icon(
        hasDate ? Icons.calendar_today : Icons.calendar_today_outlined,
        color: color,
      ),
      title: Text(displayText, style: TextStyle(color: color)),
      trailing: hasDate
          ? IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => setState(() {
                _dueDate = null;
                _repeatType = RepeatType.none;
              }),
            )
          : null,
      onTap: () => _showDatePicker(),
    );
  }

  /// 显示日期选择器
  Future<void> _showDatePicker() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  /// 构建提醒选项
  Widget _buildReminderOption(ThemeData theme) {
    final hasReminder = _reminder != null;
    final color = hasReminder 
        ? theme.colorScheme.primary 
        : theme.colorScheme.onSurfaceVariant;
    
    String displayText = '提醒我';
    if (hasReminder) {
      displayText = DateFormat('M月d日 HH:mm').format(_reminder!);
    }

    return ListTile(
      leading: Icon(
        hasReminder ? Icons.notifications : Icons.notifications_outlined,
        color: color,
      ),
      title: Text(displayText, style: TextStyle(color: color)),
      trailing: hasReminder
          ? IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => setState(() => _reminder = null),
            )
          : null,
      onTap: () => _showDateTimePicker(),
    );
  }

  /// 显示日期时间选择器
  Future<void> _showDateTimePicker() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _reminder ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (pickedDate == null || !mounted) return;
    
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_reminder ?? now),
    );
    if (pickedTime == null) return;
    
    setState(() {
      _reminder = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  /// 构建重复选项
  Widget _buildRepeatOption(ThemeData theme) {
    final hasRepeat = _repeatType != RepeatType.none;
    final color = hasRepeat 
        ? theme.colorScheme.primary 
        : theme.colorScheme.onSurfaceVariant;
    
    final repeatText = switch (_repeatType) {
      RepeatType.none => '重复',
      RepeatType.daily => '每天',
      RepeatType.weekdays => '工作日',
      RepeatType.weekly => '每周',
      RepeatType.monthly => '每月',
      RepeatType.yearly => '每年',
    };

    return ListTile(
      leading: Icon(
        hasRepeat ? Icons.repeat : Icons.repeat_outlined,
        color: color,
      ),
      title: Text(repeatText, style: TextStyle(color: color)),
      trailing: hasRepeat
          ? IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => setState(() => _repeatType = RepeatType.none),
            )
          : null,
      onTap: () => _showRepeatPicker(),
    );
  }

  /// 显示重复选择器
  void _showRepeatPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('每天'),
            onTap: () {
              setState(() => _repeatType = RepeatType.daily);
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text('工作日'),
            onTap: () {
              setState(() => _repeatType = RepeatType.weekdays);
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text('每周'),
            onTap: () {
              setState(() => _repeatType = RepeatType.weekly);
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text('每月'),
            onTap: () {
              setState(() => _repeatType = RepeatType.monthly);
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text('每年'),
            onTap: () {
              setState(() => _repeatType = RepeatType.yearly);
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// 构建列表选择器
  Widget _buildListSelector(ThemeData theme) {
    final lists = ref.watch(availableListsProvider);
    final currentList = lists.firstWhere(
      (l) => l.id == _selectedListId,
      orElse: () => lists.first,
    );

    return ListTile(
      leading: Icon(
        Icons.list,
        color: currentList.themeColor.color,
      ),
      title: Text(currentList.name),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showListPicker(lists),
    );
  }

  /// 显示列表选择器
  void _showListPicker(List<TaskList> lists) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '选择列表',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ...lists.map((list) => ListTile(
            leading: Icon(list.icon, color: list.themeColor.color),
            title: Text(list.name),
            trailing: _selectedListId == list.id 
                ? const Icon(Icons.check, color: Colors.green)
                : null,
            onTap: () {
              setState(() => _selectedListId = list.id);
              Navigator.pop(context);
            },
          )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// 构建备注输入框
  Widget _buildNoteInput(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _noteController,
        maxLines: null,
        minLines: 2,
        decoration: InputDecoration(
          hintText: '添加备注',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: theme.colorScheme.outline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: theme.colorScheme.outline.withOpacity(0.3),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建保存按钮
  Widget _buildSaveButton(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _titleController.text.trim().isNotEmpty ? _saveTask : null,
          child: Text(_isEditing ? '保存' : '创建任务'),
        ),
      ),
    );
  }

  /// 构建删除按钮
  Widget _buildDeleteButton(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SizedBox(
        width: double.infinity,
        child: TextButton(
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('确认删除'),
                content: Text('确定要删除任务「${widget.existingTask!.title}」吗？'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('删除'),
                  ),
                ],
              ),
            );
            if (confirmed == true && mounted) {
              await ref.read(todoServiceProvider.notifier)
                  .removeTask(widget.existingTask!);
              if (mounted) Navigator.pop(context);
            }
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('删除任务'),
        ),
      ),
    );
  }
}
