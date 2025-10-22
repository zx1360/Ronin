import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:torrid/features/todo/models/task_list.dart';
import 'package:torrid/features/todo/models/todo_task.dart';
import 'package:torrid/features/todo/providers/box_provider.dart';
import 'package:torrid/features/todo/providers/content_notifier.dart';
import 'package:torrid/features/todo/providers/status_provider.dart';
import 'package:torrid/shared/utils/util.dart';

part 'notifier_provider.g.dart';

class Cashier {
  final Box<TaskList> taskListBox;

  Cashier({required this.taskListBox});
}

@riverpod
class TodoService extends _$TodoService {
  @override
  Cashier build() {
    initDefault();
    return Cashier(taskListBox: ref.read(taskListBoxProvider));
  }

  // ----初始化----
  // 如果Box中记录为空, 则创建默认taskList.
  Future<void> initDefault() async {
    final listBox = ref.read(taskListBoxProvider);
    print(listBox.values.length);
    if (listBox.values.length < 4) {
      await listBox.clear();
      await Future.wait([
        addList("我的一天", isDefault: true),
        addList("重要", isDefault: true),
        addList("计划内", isDefault: true),
        addList("任务", isDefault: true),
      ]);
    }

    // 操!
    ref
        .read(contentServiceProvider.notifier)
        .switchList(
          list: listBox.values.where((l) => l.name == "我的一天").first,
        );
    print(ref.read(contentServiceProvider));
    // for(final a in ref.read(taskListProvider)){
    //   print(a.name);
    // }
    // ref
    //     .read(contentServiceProvider.notifier)
    //     .switchList(
    //       list: ref.read(taskListProvider).where((l) => l.name == "我的一天").first,
    //     );
    // print(ref.read(contentServiceProvider));
  }

  // ----任务列表CRUD----
  // 新增任务列表
  Future<void> addList(String title, {bool isDefault = false}) async {
    final newList = TaskList(
      id: generateId(),
      name: title,
      isDefault: isDefault,
    );
    await state.taskListBox.put(newList.id, newList);
  }

  // 删除任务列表
  Future<void> removeList(TaskList list) async {
    await state.taskListBox.delete(list.id);
  }

  // 编辑列表
  Future<void> editList(TaskList list) async {
    await state.taskListBox.put(list.id, list);
  }

  // ----任务项CRUD----
  // 添加任务
  Future<void> addTask(String listId, TodoTask task) async {
    final listBox = state.taskListBox;
    final list = listBox.get(listId)!;
    final tasks = List.of(list.tasks)
      ..removeWhere((t) => t.id == task.id)
      ..add(task);

    await state.taskListBox.put(listId, list.copyWith(tasks: tasks));
  }

  // 删除任务
  Future<void> removeTask(String listId, TodoTask task) async {
    final listBox = state.taskListBox;
    final list = listBox.get(listId)!;
    final tasks = List.of(list.tasks)..removeWhere((t) => t.id == task.id);

    await state.taskListBox.put(listId, list.copyWith(tasks: tasks));
  }

  // 编辑任务
  Future<void> editTask({
    required String initialListId,
    required String selectedListId,
    required TodoTask task,
  }) async {
    final listBox = state.taskListBox;
    if (initialListId != selectedListId) {
      await listBox.delete(initialListId);
    }

    await addTask(selectedListId, task);
  }

  // ----任务项-任务列表关系----
  // 任务分类
  Future<void> classifyTask(TodoTask task, TaskList list) async {}
}
