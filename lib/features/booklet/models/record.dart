import 'package:hive/hive.dart';
import 'package:torrid/features/booklet/models/style.dart';
import 'package:torrid/features/booklet/models/task.dart';
import 'package:torrid/features/booklet/services/booklet_hive_service.dart';
import 'package:torrid/shared/utils/util.dart';

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

  factory Record.empty({required Style style}) {
    final Map<String, bool> taskCompletion = {};
    for (Task task in style.tasks) {
      taskCompletion.addAll({task.id: false});
    }
    return Record(
      id: Util.generateId(),
      styleId: style.id,
      date: Util.getTodayDate(),
      message: "",
      taskCompletion: taskCompletion,
    );
  }

  factory Record.fromJson(Map<String, dynamic> json) {
    final taskCompletions = (json['taskCompletion'] as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, v as bool));
    return Record(
      id: (json['id'] as String).length < 17 ? Util.generateId() : json['id'],
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
