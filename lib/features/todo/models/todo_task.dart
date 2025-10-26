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

@HiveType(typeId: 17)
enum RepeatCycle {
  @HiveField(0)
  @JsonValue('once')
  once,
  @HiveField(1)
  @JsonValue('everyday')
  everyday,
  @HiveField(2)
  @JsonValue('workday')
  workday,
  @HiveField(3)
  @JsonValue('weekend')
  weekend,
  @HiveField(4)
  @JsonValue('everyWeek')
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
  final bool isMarked;

  @HiveField(5)
  final DateTime? dueDate;

  @HiveField(6)
  final DateTime? reminder;

  @HiveField(7)
  final Priority priority;

  @HiveField(8)
  final RepeatCycle? repeatCycle;

  @HiveField(9)
  final DateTime createAt;

  TodoTask({
    required this.id,
    required this.title,
    required this.desc,
    required this.isDone,
    required this.isMarked,
    required this.dueDate,
    required this.reminder,
    required this.priority,
    required this.repeatCycle,
    DateTime? createAt,
  }) : createAt = createAt ?? DateTime.now();

  TodoTask copyWith({
    String? id,
    String? title,
    String? desc,
    bool? isDone,
    bool? isMarked,
    DateTime? dueDate,
    DateTime? reminder,
    Priority? priority,
    RepeatCycle? repeatCycle,
    DateTime? createAt,
  }) {
    return TodoTask(
      id: id ?? this.id,
      title: title ?? this.title,
      desc: desc ?? this.desc,
      isDone: isDone ?? this.isDone,
      isMarked: isMarked?? this.isMarked,
      dueDate: dueDate ?? this.dueDate,
      reminder: reminder ?? this.reminder,
      priority: priority ?? this.priority,
      repeatCycle: repeatCycle ?? this.repeatCycle,
      createAt: createAt ?? this.createAt,
    );
  }

  factory TodoTask.fromJson(Map<String, dynamic> json) =>
      _$TodoTaskFromJson(json);
  Map<String, dynamic> toJson() => _$TodoTaskToJson(this);
}
