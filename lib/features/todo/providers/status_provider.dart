import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:torrid/features/todo/models/task_list.dart';
import 'package:torrid/features/todo/providers/box_provider.dart';

part 'status_provider.g.dart';

// taskList记录
@riverpod
List<TaskList> taskList(TaskListRef ref) {
  final asyncVal = ref.watch(taskListStreamProvider);
  if (asyncVal.hasError) {
    throw asyncVal.error!;
  }
  final vals = asyncVal.asData?.value ?? [];
  return vals..sort((a, b) => a.order.compareTo(b.order));
}

// ----业务相关数据----
@riverpod
TaskList listWithId(ListWithIdRef ref, String listId) {
  return ref.read(taskListProvider).where((l) => l.id == listId).first;
}

// 根据列表名找到list(默认列表中)
@riverpod
TaskList listWithName(ListWithNameRef ref, String listName) {
  final box = ref.read(taskListBoxProvider);
  return box.values.firstWhere((l) => l.isDefault && l.name == listName);
}

// 根据taskId找到list.
@riverpod
TaskList listWithTaskId(ListWithTaskIdRef ref, String taskId) {
  final box = ref.read(taskListBoxProvider);
  return box.values
      .where((l) => l.tasks.map((t) => t.id).contains(taskId))
      .first;
}

// 新增task时, 可供作为'所属列表'的list.
@riverpod
List<TaskList> availableLists(AvailableListsRef ref) {
  final lists = ref.watch(taskListProvider);
  return (lists
        .where((l) => l.isDefault && l.name == "任务" || !l.isDefault)
        .toList()
    ..sort((a, b) {
      if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
      return 0;
    })).toList();
}
