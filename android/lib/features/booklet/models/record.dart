import 'package:json_annotation/json_annotation.dart';
import 'package:torrid/features/booklet/models/style.dart';
import 'package:torrid/features/booklet/models/task.dart';
import 'package:torrid/core/models/mood.dart';
import 'package:torrid/core/utils/serialization.dart';
import 'package:torrid/core/utils/util.dart';

part 'record.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class Record {

  final String id;

  final String styleId;

  @JsonKey(fromJson: dateFromJson, toJson: dateToJson)
  late final DateTime date;

  String message;

  late final Map<String, bool> taskCompletion;

  @MoodTypeConverter()
  MoodType? mood;

  final DateTime? updatedAt;

  Record({
    this.updatedAt,
    required this.id,
    required this.styleId,
    required this.date,
    required this.message,
    required this.taskCompletion,
    this.mood,
  });

  Record copyWith({
    DateTime? updatedAt,
    String? id,
    String? styleId,
    DateTime? date,
    String? message,
    Map<String, bool>? taskCompletion,
    MoodType? mood,
    bool clearMood = false,
  }) {
    return Record(
      updatedAt: updatedAt ?? this.updatedAt,
      id: id ?? this.id,
      styleId: styleId ?? this.styleId,
      date: date ?? this.date,
      message: message ?? this.message,
      taskCompletion: Map.of(taskCompletion ?? this.taskCompletion),
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
