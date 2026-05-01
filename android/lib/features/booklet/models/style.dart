import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:torrid/core/utils/serialization.dart';
import 'package:torrid/features/booklet/models/task.dart';
import 'package:torrid/core/utils/util.dart';

part 'style.g.dart';

@HiveType(typeId: 10)
@JsonSerializable(fieldRename: FieldRename.snake)
class Style {
  @HiveField(0)
  final String id;

  @HiveField(1)
  @JsonKey(
    fromJson: dateFromJson,
    toJson: dateToJson,
  )
  final DateTime startDate;

  @HiveField(2)
  final int validCheckIn;

  @HiveField(3)
  final int fullyDone;

  @HiveField(4)
  final int longestStreak;

  @HiveField(5)
  final int longestFullyStreak;

  @HiveField(6)
  final List<Task> tasks;

  Style({
    required this.id,
    required this.startDate,
    required this.validCheckIn,
    required this.fullyDone,
    required this.longestStreak,
    required this.longestFullyStreak,
    required this.tasks,
  });

  Style copyWith({
    String? id,
    DateTime? startDate,
    int? validCheckIn,
    int? fullyDone,
    int? longestStreak,
    int? longestFullyStreak,
    List<Task>? tasks,
  }) {
    return Style(
      id: id ?? this.id,
      startDate: startDate ?? this.startDate,
      validCheckIn: validCheckIn ?? this.validCheckIn,
      fullyDone: fullyDone ?? this.fullyDone,
      longestStreak: longestStreak ?? this.longestStreak,
      longestFullyStreak: longestFullyStreak ?? this.longestFullyStreak,
      tasks: tasks ?? this.tasks,
    );
  }

  factory Style.newOne(DateTime date, List<Task> tasks) {
    return Style(
      id: generateId(),
      startDate: date,
      validCheckIn: 0,
      fullyDone: 0,
      longestStreak: 0,
      longestFullyStreak: 0,
      tasks: tasks,
    );
  }

  factory Style.fromJson(Map<String, dynamic> json) => _$StyleFromJson(json);
  Map<String, dynamic> toJson() => _$StyleToJson(this);
}
