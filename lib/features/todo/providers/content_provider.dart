/// Todo 模块的当前选中状态管理
///
/// 管理当前选中/正在查看的任务列表。
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/todo/models/task_list.dart';
import 'package:torrid/features/todo/providers/notifier_provider.dart';

part 'content_provider.g.dart';

/// 当前选中的任务列表
/// 
/// 用于 Todo 页面显示当前正在查看的任务列表。
/// 
/// **重命名说明**: 原名 `Content`，为提高可读性可考虑重命名为 `SelectedTaskList`。
/// 生成的 provider 名称保持 `contentProvider` 以保持向后兼容。
@riverpod
class Content extends _$Content {
  @override
  TaskList? build() {
    // 延迟初始化，确保 Box 已准备好
    Future(initDefault);
    return null;
  }

  /// 初始化默认任务列表
  Future<void> initDefault() async {
    await ref.read(todoServiceProvider.notifier).initDefault();
    final defaultList = ref
        .read(todoServiceProvider)
        .taskListBox
        .values
        .firstWhere((l) => l.name == '任务');
    switchList(defaultList);
  }

  /// 切换当前选中的任务列表
  void switchList(TaskList list) {
    state = list;
  }

  /// 切换到默认任务列表
  void switchToDefault() {
    final defaultList = ref
        .read(todoServiceProvider)
        .taskListBox
        .values
        .firstWhere((l) => l.name == '任务');
    switchList(defaultList);
  }
}
