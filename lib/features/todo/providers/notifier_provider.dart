/// Todo 模块的核心业务逻辑服务
///
/// 提供任务列表和任务的增删改查功能。
/// 参考 Microsoft To-Do 设计，任务独立存储，与列表解耦。
library;

import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:torrid/features/todo/models/task_list.dart';
import 'package:torrid/features/todo/models/todo_task.dart';
import 'package:torrid/features/todo/providers/box_provider.dart';
import 'package:torrid/features/todo/services/todo_notification_service.dart';
import 'package:torrid/core/utils/util.dart';

part 'notifier_provider.g.dart';

// ============================================================================
// 数据仓库
// ============================================================================

/// Todo 模块的数据仓库
/// 
/// 封装对 [TaskList] 和 [TodoTask] Box 的访问。
class TodoRepository {
  final Box<TaskList> listBox;
  final Box<TodoTask> taskBox;

  const TodoRepository({
    required this.listBox,
    required this.taskBox,
  });
}

// ============================================================================
// Todo 服务
// ============================================================================

/// Todo 模块的核心服务
/// 
/// 提供以下功能：
/// - 任务列表 CRUD 操作
/// - 任务 CRUD 操作
/// - 智能列表支持（我的一天、重要、计划内等）
@riverpod
class TodoService extends _$TodoService {
  @override
  TodoRepository build() {
    return TodoRepository(
      listBox: ref.read(taskListBoxProvider),
      taskBox: ref.read(todoTaskBoxProvider),
    );
  }

  // --------------------------------------------------------------------------
  // 初始化
  // --------------------------------------------------------------------------

  /// 初始化默认任务列表
  /// 
  /// 如果 Box 为空，创建默认的"任务"列表。
  Future<void> initDefault() async {
    final listBox = state.listBox;
    if (listBox.values.isEmpty) {
      await listBox.clear();
      await addList("任务", isDefault: true);
    }
  }

  // --------------------------------------------------------------------------
  // 任务列表 CRUD
  // --------------------------------------------------------------------------

  /// 新增任务列表
  /// 
  /// 如果列表名称已存在，则不创建。
  Future<TaskList?> addList(
    String title, {
    bool isDefault = false,
    ListThemeColor themeColor = ListThemeColor.blue,
  }) async {
    title = title.trim();
    if (title.isEmpty) return null;
    
    // 检查名称是否重复
    if (state.listBox.values.any((list) => list.name == title)) {
      return null;
    }
    
    final newList = TaskList(
      id: generateId(),
      name: title,
      order: state.listBox.length,
      isDefault: isDefault,
      themeColor: themeColor,
    );
    await state.listBox.put(newList.id, newList);
    return newList;
  }

  /// 编辑任务列表
  Future<void> editList(
    TaskList list, {
    String? name,
    ListThemeColor? themeColor,
    int? newOrder,
  }) async {
    final listBox = state.listBox;
    
    // 处理排序变更
    if (newOrder != null && list.order != newOrder) {
      final lists = listBox.values.toList();
      if (list.order < newOrder) {
        // 向后移动：中间的列表前移
        for (final l in lists) {
          if (l.order > list.order && l.order <= newOrder) {
            await listBox.put(l.id, l.copyWith(order: l.order - 1));
          }
        }
      } else {
        // 向前移动：中间的列表后移
        for (final l in lists) {
          if (l.order < list.order && l.order >= newOrder) {
            await listBox.put(l.id, l.copyWith(order: l.order + 1));
          }
        }
      }
    }

    await listBox.put(
      list.id,
      list.copyWith(
        name: name ?? list.name,
        themeColor: themeColor,
        order: newOrder,
      ),
    );
  }

  /// 删除任务列表
  /// 
  /// 同时删除列表中的所有任务。
  Future<void> removeList(TaskList list) async {
    // 删除列表中的所有任务
    final tasksToDelete = state.taskBox.values
        .where((t) => t.listId == list.id)
        .toList();
    for (final task in tasksToDelete) {
      await state.taskBox.delete(task.id);
    }
    
    // 删除列表
    await state.listBox.delete(list.id);
    
    // 调整后续列表的顺序
    for (final listToMinus in state.listBox.values.where(
      (l) => l.order > list.order,
    )) {
      await state.listBox.put(
        listToMinus.id,
        listToMinus.copyWith(order: listToMinus.order - 1),
      );
    }
  }

  /// 重命名任务列表
  Future<void> renameList(TaskList list, String name) async {
    name = name.trim();
    if (name.isEmpty) return;
    await state.listBox.put(list.id, list.copyWith(name: name));
  }

  // --------------------------------------------------------------------------
  // 任务 CRUD
  // --------------------------------------------------------------------------

  /// 快速添加任务（仅标题）
  Future<TodoTask> quickAddTask({
    required String title,
    required String listId,
    bool addToMyDay = false,
    bool isImportant = false,
    DateTime? dueDate,
  }) async {
    final task = TodoTask(
      id: generateId(),
      title: title.trim(),
      listId: listId,
      isMyDay: addToMyDay,
      myDayDate: addToMyDay ? DateTime.now() : null,
      priority: isImportant ? Priority.important : Priority.normal,
      dueDate: dueDate,
    );
    await state.taskBox.put(task.id, task);
    
    // 安排到期提醒通知
    if (dueDate != null) {
      TodoNotificationService.instance.scheduleTaskDueNotification(task);
    }
    
    return task;
  }

  /// 添加完整任务
  Future<TodoTask> addTask(TodoTask task) async {
    await state.taskBox.put(task.id, task);
    
    // 安排通知
    if (task.dueDate != null) {
      TodoNotificationService.instance.scheduleTaskDueNotification(task);
    }
    if (task.reminder != null) {
      TodoNotificationService.instance.scheduleTaskReminderNotification(task);
    }
    
    return task;
  }

  /// 更新任务
  Future<void> updateTask(TodoTask task) async {
    await state.taskBox.put(task.id, task);
    
    // 更新通知
    if (task.isDone) {
      // 已完成的任务取消所有通知
      TodoNotificationService.instance.cancelTaskNotification(task.id);
      TodoNotificationService.instance.cancelTaskReminderNotification(task.id);
    } else {
      // 重新安排通知
      if (task.dueDate != null) {
        TodoNotificationService.instance.scheduleTaskDueNotification(task);
      } else {
        TodoNotificationService.instance.cancelTaskNotification(task.id);
      }
      if (task.reminder != null) {
        TodoNotificationService.instance.scheduleTaskReminderNotification(task);
      } else {
        TodoNotificationService.instance.cancelTaskReminderNotification(task.id);
      }
    }
  }

  /// 删除任务
  Future<void> removeTask(TodoTask task) async {
    // 取消相关通知
    TodoNotificationService.instance.cancelTaskNotification(task.id);
    TodoNotificationService.instance.cancelTaskReminderNotification(task.id);
    
    await state.taskBox.delete(task.id);
  }

  /// 切换任务完成状态
  Future<void> toggleTaskDone(TodoTask task) async {
    final now = DateTime.now();
    final updatedTask = task.copyWith(
      isDone: !task.isDone,
      completedAt: !task.isDone ? now : null,
      clearCompletedAt: task.isDone, // 取消完成时清除完成时间
    );
    await state.taskBox.put(task.id, updatedTask);
    
    // 完成任务时取消通知，取消完成时重新安排
    if (updatedTask.isDone) {
      TodoNotificationService.instance.cancelTaskNotification(task.id);
      TodoNotificationService.instance.cancelTaskReminderNotification(task.id);
    } else {
      if (updatedTask.dueDate != null) {
        TodoNotificationService.instance.scheduleTaskDueNotification(updatedTask);
      }
      if (updatedTask.reminder != null) {
        TodoNotificationService.instance.scheduleTaskReminderNotification(updatedTask);
      }
    }
  }

  /// 切换任务重要状态
  Future<void> toggleTaskImportant(TodoTask task) async {
    final updatedTask = task.copyWith(
      priority: task.isImportant ? Priority.normal : Priority.important,
    );
    await state.taskBox.put(task.id, updatedTask);
  }

  /// 切换任务"我的一天"状态
  Future<void> toggleTaskMyDay(TodoTask task) async {
    final now = DateTime.now();
    final updatedTask = task.copyWith(
      isMyDay: !task.isMyDay,
      myDayDate: !task.isMyDay ? now : null,
      clearMyDayDate: task.isMyDay,
    );
    await state.taskBox.put(task.id, updatedTask);
  }

  /// 设置任务截止日期
  Future<void> setTaskDueDate(TodoTask task, DateTime? dueDate) async {
    final updatedTask = task.copyWith(
      dueDate: dueDate,
      clearDueDate: dueDate == null,
    );
    await state.taskBox.put(task.id, updatedTask);
  }

  /// 设置任务提醒
  Future<void> setTaskReminder(TodoTask task, DateTime? reminder) async {
    final updatedTask = task.copyWith(
      reminder: reminder,
      clearReminder: reminder == null,
    );
    await state.taskBox.put(task.id, updatedTask);
  }

  /// 移动任务到其他列表
  Future<void> moveTaskToList(TodoTask task, String newListId) async {
    if (task.listId == newListId) return;
    final updatedTask = task.copyWith(listId: newListId);
    await state.taskBox.put(task.id, updatedTask);
  }

  // --------------------------------------------------------------------------
  // 子任务/步骤 CRUD
  // --------------------------------------------------------------------------

  /// 添加步骤
  Future<void> addStep(TodoTask task, String stepTitle) async {
    stepTitle = stepTitle.trim();
    if (stepTitle.isEmpty) return;
    
    final newStep = TodoStep(
      id: generateId(),
      title: stepTitle,
    );
    final updatedSteps = [...task.steps, newStep];
    await state.taskBox.put(task.id, task.copyWith(steps: updatedSteps));
  }

  /// 更新步骤
  Future<void> updateStep(TodoTask task, TodoStep step, {String? title, bool? isDone}) async {
    final updatedSteps = task.steps.map((s) {
      if (s.id == step.id) {
        return s.copyWith(
          title: title ?? s.title,
          isDone: isDone ?? s.isDone,
        );
      }
      return s;
    }).toList();
    await state.taskBox.put(task.id, task.copyWith(steps: updatedSteps));
  }

  /// 删除步骤
  Future<void> removeStep(TodoTask task, TodoStep step) async {
    final updatedSteps = task.steps.where((s) => s.id != step.id).toList();
    await state.taskBox.put(task.id, task.copyWith(steps: updatedSteps));
  }

  /// 切换步骤完成状态
  Future<void> toggleStepDone(TodoTask task, TodoStep step) async {
    await updateStep(task, step, isDone: !step.isDone);
  }
}
