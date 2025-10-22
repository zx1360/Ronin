import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'todo_task.g.dart';

enum Priority {
  @JsonValue('low')
  low,
  @JsonValue('medium')
  medium,
  @JsonValue('high')
  high,
  @JsonValue('intensive')
  intensive,
}

enum RepeatCycle {
  @JsonValue('once')
  once,
  @JsonValue('everyday')
  everyday,
  @JsonValue('workday')
  workday,
  @JsonValue('weekend')
  weekend,
  @JsonValue('everyday')
  everyWeek,
}

// todo页的任务数据类.
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
  final RepeatCycle? repeatCycle;

  @HiveField(8)
  final DateTime createAt;

  TodoTask({
    required this.id,
    required this.title,
    required this.desc,
    required this.isDone,
    required this.dueDate,
    required this.reminder,
    required this.priority,
    required this.repeatCycle,
    DateTime? createAt,
  }) : createAt = createAt ?? DateTime.now();
}
