/// Todo 模块的核心业务逻辑服务
///
/// 提供任务列表和任务的增删改查功能。
library;

import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:torrid/features/todo/models/task_list.dart';
import 'package:torrid/features/todo/models/todo_task.dart';
import 'package:torrid/features/todo/providers/box_provider.dart';
import 'package:torrid/features/todo/providers/content_provider.dart';
import 'package:torrid/features/todo/providers/status_provider.dart';
import 'package:torrid/core/utils/util.dart';

part 'notifier_provider.g.dart';

// ============================================================================
// 数据仓库
// ============================================================================

/// Todo 模块的数据仓库
/// 
/// 封装对 [TaskList] Box 的访问。
/// 
/// **重构说明**: 原名 `Cashier`，重命名为语义更清晰的 `TodoRepository`。
class TodoRepository {
  final Box<TaskList> taskListBox;

  const TodoRepository({required this.taskListBox});
}

// ============================================================================
// Todo 服务
// ============================================================================

/// Todo 模块的核心服务
/// 
/// 提供以下功能：
/// - 任务列表 CRUD 操作
/// - 任务 CRUD 操作
/// - 列表排序管理
@riverpod
class TodoService extends _$TodoService {
  @override
  TodoRepository build() {
    return TodoRepository(taskListBox: ref.read(taskListBoxProvider));
  }

  // --------------------------------------------------------------------------
  // 初始化
  // --------------------------------------------------------------------------

  /// 初始化默认任务列表
  /// 
  /// 如果 Box 为空，创建"计划内"和"任务"两个默认列表。
  Future<void> initDefault() async {
    final listBox = state.taskListBox;
    if (listBox.values.isEmpty) {
      await listBox.clear();
      await addList("计划内", isDefault: true);
      await addList("任务", isDefault: true);
    }
  }

  // --------------------------------------------------------------------------
  // 任务列表 CRUD
  // --------------------------------------------------------------------------

  /// 新增任务列表
  /// 
  /// 如果列表名称已存在，则不创建。
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

  /// 编辑任务列表（名称和排序）
  Future<void> editList(
    TaskList list, {
    required String name,
    required int newOrder,
  }) async {
    final listBox = state.taskListBox;
    final lists = listBox.values.toList();

    // 调整受影响的列表顺序
    if (list.order < newOrder) {
      // 向后移动：中间的列表前移
      for (final l in lists) {
        if (l.order > list.order && l.order <= newOrder) {
          await listBox.put(l.id, l.copyWith(order: l.order - 1));
        }
      }
    } else if (list.order > newOrder) {
      // 向前移动：中间的列表后移
      for (final l in lists) {
        if (l.order < list.order && l.order >= newOrder) {
          await listBox.put(l.id, l.copyWith(order: l.order + 1));
        }
      }
    }

    await listBox.put(list.id, list.copyWith(order: newOrder, name: name));
  }

  /// 删除任务列表
  /// 
  /// 同时调整其他列表的顺序。
  Future<void> removeList(TaskList list) async {
    await state.taskListBox.delete(list.id);
    
    // 调整后续列表的顺序
    for (final listToMinus in state.taskListBox.values.where(
      (l) => l.order > list.order,
    )) {
      await state.taskListBox.put(
        listToMinus.id,
        listToMinus.copyWith(order: listToMinus.order - 1),
      );
    }
  }

  /// 重命名任务列表
  Future<void> rename(TaskList list, String name) async {
    await state.taskListBox.put(list.id, list.copyWith(name: name));
  }

  // --------------------------------------------------------------------------
  // 任务 CRUD
  // --------------------------------------------------------------------------

  /// 切换任务完成状态
  Future<void> toggleTask(TodoTask task, bool isDone) async {
    final list = ref.read(listWithTaskIdProvider(task.id));
    final listBox = state.taskListBox;
    
    final updatedTasks = list.tasks.map((t) {
      if (t.id == task.id) {
        return t.copyWith(
          isDone: isDone,
          doneAt: isDone ? DateTime.now() : null,
        );
      }
      return t;
    }).toList();
    
    final updatedList = list.copyWith(tasks: updatedTasks);
    await listBox.put(list.id, updatedList);
    ref.read(contentProvider.notifier).switchList(updatedList);
  }

  /// 添加任务到指定列表
  Future<void> addTask(String listId, TodoTask task) async {
    final listBox = state.taskListBox;
    final list = listBox.get(listId)!;
    
    final tasks = List<TodoTask>.from(list.tasks)
      ..removeWhere((t) => t.id == task.id)
      ..add(task);

    await state.taskListBox.put(listId, list.copyWith(tasks: tasks));
  }

  /// 从指定列表删除任务
  Future<void> removeTask(String listId, TodoTask task) async {
    final listBox = state.taskListBox;
    final list = listBox.get(listId)!;

    final newList = list.copyWith(
      tasks: List<TodoTask>.from(list.tasks)
        ..removeWhere((t) => t.id == task.id),
    );

    await state.taskListBox.put(listId, newList);
    ref.read(contentProvider.notifier).switchList(newList);
  }

  /// 编辑任务
  /// 
  /// 支持跨列表移动任务。
  Future<void> editTask({
    required String initialListId,
    required String selectedListId,
    required TodoTask task,
  }) async {
    // 如果列表变更，先从原列表删除
    if (initialListId != selectedListId) {
      await removeTask(initialListId, task);
    }

    await addTask(selectedListId, task);
  }

  /// 任务分类（预留接口）
  Future<void> classifyTask(TodoTask task, TaskList list) async {
    // TODO: 实现任务分类逻辑
  }
}
