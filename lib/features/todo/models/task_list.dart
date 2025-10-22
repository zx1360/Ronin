import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:torrid/features/todo/models/todo_task.dart';

part 'task_list.g.dart';

@JsonSerializable()
@HiveType(typeId: 18)
class TaskList {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final List<TodoTask> tasks;

  @HiveField(3)
  final bool isDefault;

  // TODO: 开放图标emoj作为列表图标.
  // @HiveField(4)
  // final String? icon;

  TaskList({
    required this.id,
    required this.name,
    this.tasks = const [],
    this.isDefault = false,
  });

  TaskList copyWith({
    String? id,
    String? name,
    List<TodoTask>? tasks,
    bool? isDefault,
  }) {
    return TaskList(
      id: id ?? this.id,
      name: name ?? this.name,
      tasks: tasks ?? this.tasks,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}
