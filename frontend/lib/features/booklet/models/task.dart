import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:torrid/core/utils/util.dart';

part 'task.g.dart';

@HiveType(typeId: 11)
@JsonSerializable(fieldRename: FieldRename.snake)
class Task {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final String image;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.image,
  });

  Task.noId({
    required this.title,
    required this.description,
    required this.image,
  }): id=generateId();

  factory Task.fromJson(Map<String, dynamic> json) => _$TaskFromJson(json);
  Map<String, dynamic> toJson() => _$TaskToJson(this);
}
