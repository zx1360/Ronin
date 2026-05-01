import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:torrid/features/booklet/models/style.dart';
import 'package:torrid/features/booklet/models/task.dart';
import 'package:torrid/core/models/mood.dart';
import 'package:torrid/core/utils/util.dart';

part 'record.g.dart';

@HiveType(typeId: 12)
@JsonSerializable(fieldRename: FieldRename.snake)
class Record {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String styleId;

  @HiveField(2)
  late final DateTime date;

  @HiveField(3)
  String message;

  @HiveField(4)
  late final Map<String, bool> taskCompletion;

  /// 心情记录 - 可选字段，兼容旧数据
  @HiveField(5)
  @MoodTypeConverter()
  MoodType? mood;

  Record({
    required this.id,
    required this.styleId,
    required this.date,
    required this.message,
    required this.taskCompletion,
    this.mood,
  });

  Record copyWith({
    String? id,
    String? styleId,
    DateTime? date,
    String? message,
    Map<String, bool>? taskCompletion,
    MoodType? mood,
    bool clearMood = false,
  }) {
    return Record(
      id: id ?? this.id,
      styleId: styleId ?? this.styleId,
      date: date ?? this.date,
      message: message ?? this.message,
      taskCompletion: taskCompletion ?? this.taskCompletion,
      mood: clearMood ? null : (mood ?? this.mood),
    );
  }

  factory Record.empty({required Style style, required DateTime date}) {
    final Map<String, bool> taskCompletion = {};
    for (Task task in style.tasks) {
      taskCompletion.addAll({task.id: false});
    }
    return Record(
      id: generateId(),
      styleId: style.id,
      date: date,
      message: "",
      taskCompletion: taskCompletion,
    );
  }

  factory Record.fromJson(Map<String, dynamic> json) => _$RecordFromJson(json);
  Map<String, dynamic> toJson() => _$RecordToJson(this);
}
