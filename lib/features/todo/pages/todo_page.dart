import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/todo/models/task_list.dart';
import 'package:torrid/features/todo/providers/content_provider.dart';
import 'package:torrid/features/todo/providers/status_provider.dart';

import 'package:torrid/features/todo/widgets/task_content/task_list_widget.dart';
import 'package:torrid/features/todo/widgets/bar/side_drawer.dart';
import 'package:torrid/features/todo/widgets/quick_add/quick_add_bar.dart';

/// Todo 主页面
/// 
/// 参考 Microsoft To-Do 设计：
/// - 侧边栏显示智能列表和自定义列表
/// - 主内容区显示任务列表
/// - 底部快速添加任务栏
class TodoPage extends ConsumerStatefulWidget {
  const TodoPage({super.key});

  @override
  ConsumerState<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends ConsumerState<TodoPage> {
  @override
  void initState() {
    super.initState();
    // 初始化默认列表
    Future.microtask(() {
      ref.read(currentViewNotifierProvider.notifier).initDefault();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentView = ref.watch(currentViewNotifierProvider);
    final viewTitle = ref.watch(currentViewTitleProvider);
    final theme = Theme.of(context);
    
    // 获取当前视图的主题颜色
    final themeColor = _getViewThemeColor(currentView);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: themeColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          viewTitle,
          style: TextStyle(
            color: themeColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      drawer: const SideDrawer(),
      body: Column(
        children: [
          // 智能列表特殊头部（如"我的一天"显示日期）
          if (currentView is SmartListView)
            _buildSmartListHeader(currentView.type, themeColor),
          
          // 任务列表内容
          const Expanded(
            child: TaskListWidget(),
          ),
          
          // 底部快速添加栏
          QuickAddBar(themeColor: themeColor),
        ],
      ),
    );
  }

  /// 获取当前视图的主题颜色
  Color _getViewThemeColor(CurrentView view) {
    final theme = Theme.of(context);
    
    return switch (view) {
      SmartListView(:final type) => switch (type) {
        SmartListType.myDay => const Color(0xFF2196F3),     // 蓝色
        SmartListType.important => const Color(0xFFE91E63), // 粉红色
        SmartListType.planned => const Color(0xFF4CAF50),   // 绿色
        SmartListType.all => theme.colorScheme.primary,
      },
      CustomListView(:final listId) => 
        ref.watch(listByIdProvider(listId))?.themeColor.color ?? 
        theme.colorScheme.primary,
    };
  }

  /// 构建智能列表头部
  Widget _buildSmartListHeader(
    SmartListType type,
    Color themeColor,
  ) {
    if (type != SmartListType.myDay) return const SizedBox.shrink();
    
    final now = DateTime.now();
    final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final weekday = weekdays[now.weekday - 1];
    final dateText = '${now.month}月${now.day}日，$weekday';
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Text(
        dateText,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 14,
        ),
      ),
    );
  }
}
