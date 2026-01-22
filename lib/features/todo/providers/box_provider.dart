/// Todo 模块的 Hive Box 提供者
///
/// 提供对 [TaskList] 和 [TodoTask] 数据的 Box 访问和响应式流。
library;

import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:torrid/features/todo/models/task_list.dart';
import 'package:torrid/features/todo/models/todo_task.dart';
import 'package:torrid/core/services/storage/hive_service.dart';

part 'box_provider.g.dart';

// ============================================================================
// 任务列表 Box
// ============================================================================

/// 任务列表的 Hive Box
@riverpod
Box<TaskList> taskListBox(TaskListBoxRef ref) {
  return Hive.box(HiveService.taskListsBoxName);
}

/// 任务列表的响应式流
@riverpod
Stream<List<TaskList>> taskListStream(TaskListStreamRef ref) async* {
  final box = ref.read(taskListBoxProvider);
  yield box.values.toList();
  await for (final event in box.watch()) {
    if (event.deleted || event.value != null) {
      yield box.values.toList();
    }
  }
}

// ============================================================================
// 任务 Box
// ============================================================================

/// 任务的 Hive Box
@riverpod
Box<TodoTask> todoTaskBox(TodoTaskBoxRef ref) {
  return Hive.box(HiveService.todoTasksBoxName);
}

/// 任务的响应式流
@riverpod
Stream<List<TodoTask>> todoTaskStream(TodoTaskStreamRef ref) async* {
  final box = ref.read(todoTaskBoxProvider);
  yield box.values.toList();
  await for (final event in box.watch()) {
    if (event.deleted || event.value != null) {
      yield box.values.toList();
    }
  }
}
