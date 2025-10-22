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
  return asyncVal.asData?.value ?? [];
}

// ----业务相关数据----
@riverpod
TaskList listWithId(ListWithIdRef ref, String listId) {
  return ref.read(taskListProvider).where((l) => l.id == listId).first;
}
