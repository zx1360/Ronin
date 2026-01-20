import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'todo_task.g.dart';

@HiveType(typeId: 16)
enum Priority {
  @HiveField(0)
  @JsonValue('low')
  low,
  @HiveField(1)
  @JsonValue('medium')
  medium,
  @HiveField(2)
  @JsonValue('high')
  high,
  @HiveField(3)
  @JsonValue('intensive')
  intensive,
}

// todo页的任务数据类.
// 后续要实现'ms todo'那样的加上循环, 事件提醒啥的话后续再说.
@JsonSerializable()
@HiveType(typeId: 19)
class TodoTask {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String? desc;

  @HiveField(3)
  final bool isDone;

  @HiveField(4)
  final DateTime? dueDate;

  @HiveField(5)
  final DateTime? reminder;

  @HiveField(6)
  final Priority priority;

  @HiveField(7)
  final DateTime createAt;

  @HiveField(8)
  final DateTime? doneAt;

  TodoTask({
    required this.id,
    required this.title,
    required this.desc,
    required this.isDone,
    required this.dueDate,
    required this.reminder,
    required this.priority,
    DateTime? createAt,
    this.doneAt
  }) :createAt = createAt ?? DateTime.now();

  TodoTask copyWith({
    String? id,
    String? title,
    String? desc,
    bool? isDone,
    bool? isMarked,
    DateTime? dueDate,
    DateTime? reminder,
    Priority? priority,
    DateTime? createAt,
    DateTime? doneAt
  }) {
    return TodoTask(
      id: id??this.id,
      title: title ?? this.title,
      desc: desc ?? this.desc,
      isDone: isDone ?? this.isDone,
      dueDate: dueDate ?? this.dueDate,
      reminder: reminder ?? this.reminder,
      priority: priority ?? this.priority,
      createAt: createAt ?? this.createAt,
      doneAt: doneAt ?? this.doneAt,
    );
  }

  factory TodoTask.fromJson(Map<String, dynamic> json) =>
      _$TodoTaskFromJson(json);
  Map<String, dynamic> toJson() => _$TodoTaskToJson(this);
}
