import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:torrid/features/todo/models/task_list.dart';
import 'package:torrid/features/todo/models/todo_task.dart';
import 'package:torrid/features/todo/providers/box_provider.dart';

part 'status_provider.g.dart';

// todoTasks记录
@riverpod
List<TodoTask> tasks(TasksRef ref){
  final asyncVal = ref.watch(taskStreamProvider);
  if(asyncVal.hasError){
    throw asyncVal.error!;
  }
  return asyncVal.asData?.value??[];
}

// taskList记录
@riverpod
List<TaskList> taskList(TaskListRef ref){
  final asyncVal = ref.watch(taskListStreamProvider);
  if(asyncVal.hasError){
    throw asyncVal.error!;
  }
  return asyncVal.asData?.value??[];
}
