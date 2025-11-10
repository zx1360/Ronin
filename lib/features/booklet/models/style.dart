import 'package:hive/hive.dart';
import 'package:torrid/features/booklet/models/task.dart';
import 'package:torrid/shared/utils/util.dart';

part 'style.g.dart';

@HiveType(typeId: 10)
class Style {
  @HiveField(0)
  final String id;

  @HiveField(1)
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

  factory Style.fromJson(Map<String, dynamic> json) {
    return Style(
      id: json['id'],
      startDate: DateTime.parse(json['startDate']),
      validCheckIn: json['validCheckIn'],
      fullyDone: json['fullyDone'],
      longestStreak: json['longestStreak'],
      longestFullyStreak: json['longestFullyStreak'],
      tasks: (json['tasks'] as List)
          .map((item) => Task.fromJson(item))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "startDate": startDate.toLocal().toString().split('.').first,
      "fullyDone": fullyDone,
      "validCheckIn": validCheckIn,
      "longestStreak": longestStreak,
      "longestFullyStreak": longestFullyStreak,
      "tasks": tasks.map((item) => item.toJson()).toList(),
    };
  }
}
