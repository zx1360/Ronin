/// Todo 模块的当前选中状态管理
///
/// 管理当前选中/正在查看的视图（智能列表或自定义列表）。
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/todo/models/task_list.dart';
import 'package:torrid/features/todo/providers/notifier_provider.dart';
import 'package:torrid/features/todo/providers/status_provider.dart';
import 'package:torrid/features/todo/services/todo_notification_service.dart';

part 'content_provider.g.dart';

/// 当前视图状态
/// 
/// 存储当前用户正在查看的视图类型（智能列表或自定义列表）
@riverpod
class CurrentViewNotifier extends _$CurrentViewNotifier {
  @override
  CurrentView build() {
    // 默认显示"我的一天"
    return const SmartListView(SmartListType.myDay);
  }

  /// 初始化默认列表
  /// 
  /// 应在 TodoPage 初始化时调用，确保 Box 已打开
  Future<void> initDefault() async {
    try {
      await ref.read(todoServiceProvider.notifier).initDefault();
      
      // 初始化通知服务并检查过期任务
      await _initNotificationsAndCheckOverdue();
    } catch (e) {
      // Box 可能还未打开，忽略错误
    }
  }

  /// 初始化通知服务并检查过期任务
  Future<void> _initNotificationsAndCheckOverdue() async {
    final notificationService = TodoNotificationService.instance;
    await notificationService.initialize();
    
    // 获取所有未完成且已过期的任务
    final allTasks = ref.read(allTasksProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    for (final task in allTasks) {
      if (task.isDone) continue;
      
      // 检查是否已过期（到期日在今天之前）
      if (task.dueDate != null) {
        final dueDate = DateTime(
          task.dueDate!.year, 
          task.dueDate!.month, 
          task.dueDate!.day,
        );
        if (dueDate.isBefore(today)) {
          // 显示过期通知（只在启动时显示一次）
          await notificationService.showOverdueNotification(task);
        } else {
          // 为未来到期的任务安排通知
          await notificationService.scheduleTaskDueNotification(task);
        }
      }
      
      // 为有提醒的任务安排通知
      if (task.reminder != null && task.reminder!.isAfter(now)) {
        await notificationService.scheduleTaskReminderNotification(task);
      }
    }
  }

  /// 切换到智能列表
  void switchToSmartList(SmartListType type) {
    state = SmartListView(type);
  }

  /// 切换到自定义列表
  void switchToCustomList(String listId) {
    state = CustomListView(listId);
  }

  /// 切换到默认列表
  void switchToDefault() {
    state = const SmartListView(SmartListType.myDay);
  }
}

/// 当前视图标题
@riverpod
String currentViewTitle(CurrentViewTitleRef ref) {
  final view = ref.watch(currentViewNotifierProvider);
  return switch (view) {
    SmartListView(:final type) => type.name,
    CustomListView(:final listId) => 
        ref.watch(listByIdProvider(listId))?.name ?? '任务',
  };
}

/// 当前视图是否为智能列表
@riverpod
bool isSmartListView(IsSmartListViewRef ref) {
  return ref.watch(currentViewNotifierProvider) is SmartListView;
}

/// 当前智能列表类型（如果是智能列表视图）
@riverpod
SmartListType? currentSmartListType(CurrentSmartListTypeRef ref) {
  final view = ref.watch(currentViewNotifierProvider);
  return view is SmartListView ? view.type : null;
}

/// 当前自定义列表 ID（如果是自定义列表视图）
@riverpod
String? currentCustomListId(CurrentCustomListIdRef ref) {
  final view = ref.watch(currentViewNotifierProvider);
  return view is CustomListView ? view.listId : null;
}

/// 当前自定义列表（如果是自定义列表视图）
@riverpod
TaskList? currentCustomList(CurrentCustomListRef ref) {
  final listId = ref.watch(currentCustomListIdProvider);
  if (listId == null) return null;
  return ref.watch(listByIdProvider(listId));
}

// ============================================================================
// 兼容旧代码（已弃用）
// ============================================================================

/// @deprecated 使用 [currentViewNotifierProvider] 替代
/// 当前选中的任务列表
@riverpod
class Content extends _$Content {
  @override
  TaskList? build() {
    // 延迟初始化，确保 Box 已准备好
    Future(initDefault);
    return null;
  }

  /// 初始化默认任务列表
  Future<void> initDefault() async {
    await ref.read(todoServiceProvider.notifier).initDefault();
    final defaultList = ref.read(defaultTaskListProvider);
    if (defaultList != null) {
      switchList(defaultList);
    }
  }

  /// 切换当前选中的任务列表
  void switchList(TaskList list) {
    state = list;
    // 同步到新的视图状态
    ref.read(currentViewNotifierProvider.notifier).switchToCustomList(list.id);
  }

  /// 切换到默认任务列表
  void switchToDefault() {
    final defaultList = ref.read(defaultTaskListProvider);
    if (defaultList != null) {
      switchList(defaultList);
    }
  }
}
