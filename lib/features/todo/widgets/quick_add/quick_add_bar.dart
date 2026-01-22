/// 底部快速添加任务栏
/// 
/// 参考 MS To-Do 设计，提供简洁的快速任务添加功能：
/// - 点击展开输入框
/// - 支持快捷设置：我的一天、截止日期、重要
/// - 回车或点击按钮添加任务
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/todo/models/task_list.dart';
import 'package:torrid/features/todo/providers/content_provider.dart';
import 'package:torrid/features/todo/providers/notifier_provider.dart';
import 'package:torrid/features/todo/providers/status_provider.dart';

class QuickAddBar extends ConsumerStatefulWidget {
  final Color themeColor;

  const QuickAddBar({
    super.key,
    required this.themeColor,
  });

  @override
  ConsumerState createState() => _QuickAddBarState();
}

class _QuickAddBarState extends ConsumerState<QuickAddBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  bool _isExpanded = false;
  bool _addToMyDay = false;
  bool _isImportant = false;
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _controller.text.isEmpty) {
        setState(() => _isExpanded = false);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// 获取当前添加任务的目标列表 ID
  String _getTargetListId() {
    final currentView = ref.read(currentViewNotifierProvider);
    return switch (currentView) {
      // 智能列表：添加到默认列表
      SmartListView() => ref.read(defaultTaskListProvider)?.id ?? '',
      // 自定义列表：添加到当前列表
      CustomListView(:final listId) => listId,
    };
  }

  /// 根据当前视图设置默认快捷选项
  void _setDefaultsForCurrentView() {
    final currentView = ref.read(currentViewNotifierProvider);
    if (currentView is SmartListView) {
      switch (currentView.type) {
        case SmartListType.myDay:
          _addToMyDay = true;
          break;
        case SmartListType.important:
          _isImportant = true;
          break;
        case SmartListType.planned:
          _dueDate = DateTime.now();
          break;
        case SmartListType.all:
          break;
      }
    }
  }

  /// 添加任务
  Future<void> _addTask() async {
    final title = _controller.text.trim();
    if (title.isEmpty) return;

    final listId = _getTargetListId();
    if (listId.isEmpty) return;

    await ref.read(todoServiceProvider.notifier).quickAddTask(
      title: title,
      listId: listId,
      addToMyDay: _addToMyDay,
      isImportant: _isImportant,
      dueDate: _dueDate,
    );

    // 重置状态
    _controller.clear();
    setState(() {
      _addToMyDay = false;
      _isImportant = false;
      _dueDate = null;
    });
    
    // 如果在智能列表视图，重新设置默认值
    _setDefaultsForCurrentView();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeColor = widget.themeColor;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withOpacity(0.3),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.all(_isExpanded ? 12 : 8),
          child: _isExpanded 
              ? _buildExpandedView(theme, themeColor)
              : _buildCollapsedView(theme, themeColor),
        ),
      ),
    );
  }

  /// 构建收起状态视图
  Widget _buildCollapsedView(ThemeData theme, Color themeColor) {
    return InkWell(
      onTap: () {
        setState(() {
          _isExpanded = true;
          _setDefaultsForCurrentView();
        });
        _focusNode.requestFocus();
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Icon(Icons.add, color: themeColor),
            const SizedBox(width: 12),
            Text(
              '添加任务',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建展开状态视图
  Widget _buildExpandedView(ThemeData theme, Color themeColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 输入框
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            decoration: InputDecoration(
              hintText: '添加任务',
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  Icons.send,
                  color: _controller.text.isNotEmpty 
                      ? themeColor 
                      : theme.colorScheme.outline,
                ),
                onPressed: _addTask,
              ),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _addTask(),
            onChanged: (_) => setState(() {}),
          ),
        ),
        
        const SizedBox(height: 8),
        
        // 快捷操作栏
        Row(
          children: [
            // 我的一天
            _buildQuickActionChip(
              icon: _addToMyDay ? Icons.wb_sunny : Icons.wb_sunny_outlined,
              label: '我的一天',
              isActive: _addToMyDay,
              activeColor: const Color(0xFF2196F3),
              onTap: () => setState(() => _addToMyDay = !_addToMyDay),
            ),
            
            const SizedBox(width: 8),
            
            // 截止日期
            _buildQuickActionChip(
              icon: _dueDate != null 
                  ? Icons.calendar_today 
                  : Icons.calendar_today_outlined,
              label: _dueDate != null ? _formatDate(_dueDate!) : '截止日期',
              isActive: _dueDate != null,
              activeColor: const Color(0xFF4CAF50),
              onTap: () => _showQuickDatePicker(),
            ),
            
            const Spacer(),
            
            // 重要标记
            IconButton(
              icon: Icon(
                _isImportant ? Icons.star : Icons.star_outline,
                color: _isImportant 
                    ? const Color(0xFFE91E63) 
                    : theme.colorScheme.outline,
              ),
              onPressed: () => setState(() => _isImportant = !_isImportant),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建快捷操作标签
  Widget _buildQuickActionChip({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final color = isActive ? activeColor : theme.colorScheme.onSurfaceVariant;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive 
              ? activeColor.withOpacity(0.1) 
              : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示快速日期选择器
  void _showQuickDatePicker() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final nextWeek = today.add(const Duration(days: 7));

    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.today, color: Color(0xFF4CAF50)),
            title: const Text('今天'),
            onTap: () {
              setState(() => _dueDate = today);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.event, color: Color(0xFF2196F3)),
            title: const Text('明天'),
            onTap: () {
              setState(() => _dueDate = tomorrow);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.date_range, color: Color(0xFF9C27B0)),
            title: const Text('下周'),
            onTap: () {
              setState(() => _dueDate = nextWeek);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(Icons.calendar_month, 
                color: Theme.of(context).colorScheme.primary),
            title: const Text('选择日期'),
            onTap: () async {
              Navigator.pop(context);
              final picked = await showDatePicker(
                context: context,
                initialDate: _dueDate ?? now,
                firstDate: now.subtract(const Duration(days: 365)),
                lastDate: now.add(const Duration(days: 365 * 5)),
              );
              if (picked != null) {
                setState(() => _dueDate = picked);
              }
            },
          ),
          if (_dueDate != null)
            ListTile(
              leading: const Icon(Icons.clear, color: Colors.grey),
              title: const Text('清除截止日期'),
              onTap: () {
                setState(() => _dueDate = null);
                Navigator.pop(context);
              },
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// 格式化日期显示
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    
    if (dateOnly == today) return '今天';
    if (dateOnly == today.add(const Duration(days: 1))) return '明天';
    return '${date.month}月${date.day}日';
  }
}
