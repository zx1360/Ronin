import 'package:hive/hive.dart';
import 'package:torrid/features/booklet/models/style.dart';
import 'package:torrid/features/booklet/models/task.dart';
import 'package:torrid/core/utils/util.dart';

part 'record.g.dart';

@HiveType(typeId: 12)
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

  Record({
    required this.id,
    required this.styleId,
    required this.date,
    required this.message,
    required this.taskCompletion,
  });

   Record copyWith({
    String? id,
    String? styleId,
    DateTime? date,
    String? message,
    Map<String, bool>? taskCompletion,
  }) {
    return Record(
      id: id ?? this.id,
      styleId: styleId ?? this.styleId,
      date: date ?? this.date,
      message: message ?? this.message,
      taskCompletion: taskCompletion ?? this.taskCompletion,
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

  factory Record.fromJson(Map<String, dynamic> json) {
    final taskCompletions = (json['taskCompletion'] as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, v as bool));
    return Record(
      id: json['id'],
      styleId: json['styleId'],
      date: DateTime.parse(json['date']),
      message: json['message'],
      taskCompletion: taskCompletions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "styleId": styleId,
      "date": date.toLocal().toString().split(".").first,
      "message": message,
      "taskCompletion": taskCompletion,
    };
  }
}
