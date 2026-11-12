import 'package:json_annotation/json_annotation.dart';
import 'package:torrid/core/utils/util.dart';

part 'task.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class Task {

  final String id;

  final String title;

  final String description;

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
