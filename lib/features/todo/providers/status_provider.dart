/// Todo 模块的派生状态提供者
///
/// 基于 Box 数据流提供经过处理的同步数据访问和业务查询。
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:torrid/features/todo/models/task_list.dart';
import 'package:torrid/features/todo/models/todo_task.dart';
import 'package:torrid/features/todo/providers/box_provider.dart';

part 'status_provider.g.dart';

// ============================================================================
// 任务列表数据
// ============================================================================

/// 所有自定义任务列表（按 order 升序排列）
@riverpod
List<TaskList> allLists(AllListsRef ref) {
  final asyncVal = ref.watch(taskListStreamProvider);
  if (asyncVal.hasError) {
    throw asyncVal.error!;
  }
  final vals = asyncVal.asData?.value ?? [];
  return vals..sort((a, b) => a.order.compareTo(b.order));
}

/// 根据列表 ID 获取任务列表
@riverpod
TaskList? listById(ListByIdRef ref, String listId) {
  final lists = ref.watch(allListsProvider);
  try {
    return lists.firstWhere((l) => l.id == listId);
  } catch (_) {
    return null;
  }
}

/// 获取默认"任务"列表
@riverpod
TaskList? defaultTaskList(DefaultTaskListRef ref) {
  final lists = ref.watch(allListsProvider);
  try {
    return lists.firstWhere((l) => l.isDefault);
  } catch (_) {
    return null;
  }
}

// ============================================================================
// 任务数据
// ============================================================================

/// 所有任务（响应式）
@riverpod
List<TodoTask> allTasks(AllTasksRef ref) {
  final asyncVal = ref.watch(todoTaskStreamProvider);
  if (asyncVal.hasError) {
    throw asyncVal.error!;
  }
  return asyncVal.asData?.value ?? [];
}

/// 根据任务 ID 获取任务
@riverpod
TodoTask? taskById(TaskByIdRef ref, String taskId) {
  final tasks = ref.watch(allTasksProvider);
  try {
    return tasks.firstWhere((t) => t.id == taskId);
  } catch (_) {
    return null;
  }
}

/// 指定列表的任务
@riverpod
List<TodoTask> tasksByListId(TasksByListIdRef ref, String listId) {
  final tasks = ref.watch(allTasksProvider);
  return tasks.where((t) => t.listId == listId).toList();
}

/// 指定列表的未完成任务数量
@riverpod
int incompleteTaskCount(IncompleteTaskCountRef ref, String listId) {
  final tasks = ref.watch(tasksByListIdProvider(listId));
  return tasks.where((t) => !t.isDone).length;
}

// ============================================================================
// 智能列表任务查询
// ============================================================================

/// "我的一天"任务（今天添加到我的一天且未完成）
@riverpod
List<TodoTask> myDayTasks(MyDayTasksRef ref) {
  final tasks = ref.watch(allTasksProvider);
  return tasks.where((t) => t.isInMyDayToday && !t.isDone).toList()
    ..sort(_taskSorter);
}

/// "我的一天"任务数量
@riverpod
int myDayTaskCount(MyDayTaskCountRef ref) {
  return ref.watch(myDayTasksProvider).length;
}

/// "重要"任务（标记为重要且未完成）
@riverpod
List<TodoTask> importantTasks(ImportantTasksRef ref) {
  final tasks = ref.watch(allTasksProvider);
  return tasks.where((t) => t.isImportant && !t.isDone).toList()
    ..sort(_taskSorter);
}

/// "重要"任务数量
@riverpod
int importantTaskCount(ImportantTaskCountRef ref) {
  return ref.watch(importantTasksProvider).length;
}

/// "计划内"任务（有截止日期且未完成）
@riverpod
List<TodoTask> plannedTasks(PlannedTasksRef ref) {
  final tasks = ref.watch(allTasksProvider);
  return tasks.where((t) => t.dueDate != null && !t.isDone).toList()
    ..sort((a, b) {
      // 按截止日期排序
      final dateCompare = a.dueDate!.compareTo(b.dueDate!);
      if (dateCompare != 0) return dateCompare;
      return _taskSorter(a, b);
    });
}

/// "计划内"任务数量
@riverpod
int plannedTaskCount(PlannedTaskCountRef ref) {
  return ref.watch(plannedTasksProvider).length;
}

/// "全部"任务（所有未完成任务）
@riverpod
List<TodoTask> allIncompleteTasks(AllIncompleteTasksRef ref) {
  final tasks = ref.watch(allTasksProvider);
  return tasks.where((t) => !t.isDone).toList()..sort(_taskSorter);
}

/// "全部"任务数量
@riverpod
int allIncompleteTaskCount(AllIncompleteTaskCountRef ref) {
  return ref.watch(allIncompleteTasksProvider).length;
}

/// 已完成任务
@riverpod
List<TodoTask> completedTasks(CompletedTasksRef ref) {
  final tasks = ref.watch(allTasksProvider);
  return tasks.where((t) => t.isDone).toList()
    ..sort((a, b) {
      // 按完成时间降序
      final aTime = a.completedAt ?? a.createdAt;
      final bTime = b.completedAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });
}

/// 指定列表的已完成任务
@riverpod
List<TodoTask> completedTasksByListId(CompletedTasksByListIdRef ref, String listId) {
  final tasks = ref.watch(tasksByListIdProvider(listId));
  return tasks.where((t) => t.isDone).toList()
    ..sort((a, b) {
      final aTime = a.completedAt ?? a.createdAt;
      final bTime = b.completedAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });
}

/// 指定列表的未完成任务
@riverpod
List<TodoTask> incompleteTasksByListId(IncompleteTasksByListIdRef ref, String listId) {
  final tasks = ref.watch(tasksByListIdProvider(listId));
  return tasks.where((t) => !t.isDone).toList()..sort(_taskSorter);
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 任务默认排序（重要优先，然后按创建时间）
int _taskSorter(TodoTask a, TodoTask b) {
  // 重要任务优先
  if (a.isImportant != b.isImportant) {
    return a.isImportant ? -1 : 1;
  }
  // 按创建时间升序
  return a.createdAt.compareTo(b.createdAt);
}

// ============================================================================
// 兼容旧代码（已弃用）
// ============================================================================

/// @deprecated 使用 [allListsProvider] 替代
@riverpod
List<TaskList> taskList(TaskListRef ref) {
  return ref.watch(allListsProvider);
}

/// @deprecated 使用 [listByIdProvider] 替代
@riverpod
TaskList listWithId(ListWithIdRef ref, String listId) {
  return ref.read(allListsProvider).firstWhere((l) => l.id == listId);
}

/// @deprecated 使用 [defaultTaskListProvider] 替代
@riverpod
TaskList listWithName(ListWithNameRef ref, String listName) {
  final box = ref.read(taskListBoxProvider);
  return box.values.firstWhere((l) => l.isDefault && l.name == listName);
}

/// @deprecated 移除 - 任务现在独立存储
@riverpod
TaskList listWithTaskId(ListWithTaskIdRef ref, String taskId) {
  final task = ref.read(taskByIdProvider(taskId));
  if (task == null) {
    throw StateError('Task not found: $taskId');
  }
  return ref.read(listByIdProvider(task.listId))!;
}

/// 新增任务时可供选择的任务列表
@riverpod
List<TaskList> availableLists(AvailableListsRef ref) {
  return ref.watch(allListsProvider);
}
