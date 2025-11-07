import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:torrid/features/todo/models/task_list.dart';
import 'package:torrid/features/todo/models/todo_task.dart';
import 'package:torrid/features/todo/providers/box_provider.dart';
import 'package:torrid/features/todo/providers/content_provider.dart';
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
    return Cashier(taskListBox: ref.read(taskListBoxProvider));
  }

  // ----初始化----
  // 如果Box中记录为空, 则创建默认taskList.
  Future<void> initDefault() async {
    final listBox = state.taskListBox;
    if (listBox.values.isEmpty) {
      await listBox.clear();
      await addList("计划内", isDefault: true);
      await addList("任务", isDefault: true);
    }
  }

  // ----任务列表CRUD----
  // 新增任务列表
  Future<void> addList(String title, {bool isDefault = false}) async {
    title = title.trim();
    final lists = ref.read(taskListProvider);
    if (lists.any((list) => list.name == title)) {
      return;
    }
    final newList = TaskList(
      id: generateId(),
      name: title,
      order: state.taskListBox.length,
      isDefault: isDefault,
    );
    await state.taskListBox.put(newList.id, newList);
  }

  /// 调整列表顺序
  /// [list] - 要调整的列表
  /// [newOrder] - 新的顺序值
  Future<void> editList(
    TaskList list, {
    required String name,
    required int newOrder,
  }) async {
    final listBox = state.taskListBox;
    final lists = listBox.values.toList();

    // 调整受影响的列表顺序
    if (list.order < newOrder) {
      for (final l in lists) {
        if (l.order > list.order && l.order <= newOrder) {
          await listBox.put(l.id, l.copyWith(order: l.order - 1));
        }
      }
    } else {
      for (final l in lists) {
        if (l.order < list.order && l.order >= newOrder) {
          await listBox.put(l.id, l.copyWith(order: l.order + 1));
        }
      }
    }

    await listBox.put(list.id, list.copyWith(order: newOrder, name: name));
  }

  // 删除列表
  Future<void> removeList(TaskList list) async {
    await state.taskListBox.delete(list.id);
    for (final listToMinus in state.taskListBox.values.where(
      (l) => l.order > list.order,
    )) {
      await state.taskListBox.put(
        listToMinus.id,
        listToMinus.copyWith(order: listToMinus.order - 1),
      );
    }
  }

  // 编辑列表
  Future<void> rename(TaskList list, String name) async {
    await state.taskListBox.put(list.id, list.copyWith(name: name));
  }

  // ----任务项CRUD----
  // 切换任务完成状态
  Future<void> toggleTask(TodoTask task, bool isDone) async {
    final list = ref.read(listWithTaskIdProvider(task.id));
    final listBox = state.taskListBox;
    // 找到要修改的任务索引并替换为新状态的任务
    final updatedTasks = list.tasks.map((t) {
      if (t.id == task.id) {
        return t.copyWith(
          isDone: isDone,
          doneAt: isDone ? DateTime.now() : null,
        );
      }
      return t;
    }).toList();
    await listBox.put(list.id, list.copyWith(tasks: updatedTasks));
    ref
        .read(contentProvider.notifier)
        .switchList(list.copyWith(tasks: updatedTasks));
  }

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

    final newList = list.copyWith(
      tasks: List.of(list.tasks)..removeWhere((t) => t.id == task.id),
    );

    await state.taskListBox.put(listId, newList);
    ref.read(contentProvider.notifier).switchList(newList);
  }

  // 编辑任务
  Future<void> editTask({
    required String initialListId,
    required String selectedListId,
    required TodoTask task,
  }) async {
    if (initialListId != selectedListId) {
      await removeTask(initialListId, task);
    }

    await addTask(selectedListId, task);
  }

  // ----任务项-任务列表关系----
  // 任务分类
  Future<void> classifyTask(TodoTask task, TaskList list) async {}
}
