import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'task_list.g.dart';

@JsonSerializable()
@HiveType(typeId: 18)
class TaskList {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final List<String> taskIds;

  @HiveField(3)
  final bool isDefault;

  // TODO: 开放图标emoj作为列表图标.
  // @HiveField(4)
  // final String? icon;

  TaskList({
    required this.id,
    required this.name,
    this.taskIds = const [],
    this.isDefault = false,
  });
}
