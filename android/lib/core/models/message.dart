import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:torrid/core/utils/serialization.dart';

part 'message.g.dart';

@HiveType(typeId: 9)
@JsonSerializable(fieldRename: FieldRename.none)
class Message {
  @HiveField(0)
  @JsonKey(fromJson: dateTimeFromJson, toJson: dateTimeToJson)
  final DateTime timestamp;

  @HiveField(1)
  final String content;

  @HiveField(2)
  @JsonKey(name: 'updated_at', includeIfNull: false)
  final DateTime? updatedAt;

  Message({required this.timestamp, required this.content, this.updatedAt});

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);
  Map<String, dynamic> toJson() => _$MessageToJson(this);
}
