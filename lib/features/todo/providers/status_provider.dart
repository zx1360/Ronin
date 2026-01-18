/// Todo 模块的派生状态提供者
///
/// 基于 Box 数据流提供经过处理的同步数据访问和业务查询。
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:torrid/features/todo/models/task_list.dart';
import 'package:torrid/features/todo/providers/box_provider.dart';

part 'status_provider.g.dart';

// ============================================================================
// 基础数据
// ============================================================================

/// 所有任务列表（按 order 升序排列）
@riverpod
List<TaskList> taskList(TaskListRef ref) {
  final asyncVal = ref.watch(taskListStreamProvider);
  if (asyncVal.hasError) {
    throw asyncVal.error!;
  }
  final vals = asyncVal.asData?.value ?? [];
  return vals..sort((a, b) => a.order.compareTo(b.order));
}

// ============================================================================
// 业务查询
// ============================================================================

/// 根据列表 ID 获取任务列表
@riverpod
TaskList listWithId(ListWithIdRef ref, String listId) {
  return ref.read(taskListProvider).firstWhere((l) => l.id == listId);
}

/// 根据列表名称获取默认任务列表
@riverpod
TaskList listWithName(ListWithNameRef ref, String listName) {
  final box = ref.read(taskListBoxProvider);
  return box.values.firstWhere((l) => l.isDefault && l.name == listName);
}

/// 根据任务 ID 找到其所属的任务列表
@riverpod
TaskList listWithTaskId(ListWithTaskIdRef ref, String taskId) {
  final box = ref.read(taskListBoxProvider);
  return box.values.firstWhere(
    (l) => l.tasks.any((t) => t.id == taskId),
  );
}

/// 新增任务时可供选择的任务列表
/// 
/// 包含默认的"任务"列表和所有非默认列表。
@riverpod
List<TaskList> availableLists(AvailableListsRef ref) {
  final lists = ref.watch(taskListProvider);
  final filtered = lists.where(
    (l) => (l.isDefault && l.name == "任务") || !l.isDefault,
  ).toList();
  
  // 默认列表排在前面
  filtered.sort((a, b) {
    if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
    return 0;
  });
  
  return filtered;
}
