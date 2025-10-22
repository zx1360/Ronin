import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:torrid/features/todo/models/task_list.dart';
import 'package:torrid/features/todo/models/todo_task.dart';
import 'package:torrid/features/todo/providers/box_provider.dart';

part 'notifier_provider.g.dart';

class Cashier {
  final Box<TodoTask> taskBox;
  final Box<TaskList> taskListBox;

  Cashier({required this.taskBox, required this.taskListBox});
}

@riverpod
class TodoService extends _$TodoService {
  @override
  Cashier build() {
    return Cashier(
      taskBox: ref.read(taskBoxProvider),
      taskListBox: ref.read(taskListBoxProvider),
    );
  }

  // ----初始化----
  // 如果Box中记录为空, 则创建默认taskList.
  Future<void> initDefault()async{

  }

  // ----新增任务列表
  Future<void> addList()async{

  }

  // 
}
