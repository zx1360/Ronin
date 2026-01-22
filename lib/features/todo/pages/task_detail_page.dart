/// 任务详情页
/// 
/// @deprecated 已弃用，功能整合到 TaskEditSheet 中
/// 保留此文件以兼容旧代码引用
library;
import 'package:flutter/material.dart';
import 'package:torrid/features/todo/models/todo_task.dart';
import 'package:torrid/features/todo/widgets/edit_sheet/edit_task_sheet.dart';

/// @deprecated 使用 [openTaskSheet] 替代
class TaskDetailPage extends StatelessWidget {
  final TodoTask task;

  const TaskDetailPage({
    super.key,
    required this.task,
  });

  @override
  Widget build(BuildContext context) {
    // 直接打开编辑弹窗并返回
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pop(context);
      openTaskSheet(context, task: task);
    });
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}