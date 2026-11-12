import 'package:json_annotation/json_annotation.dart';
import 'package:torrid/core/utils/serialization.dart';

part 'message.g.dart';

@JsonSerializable(fieldRename: FieldRename.none)
class Message {

  @JsonKey(fromJson: dateTimeFromJson, toJson: dateTimeToJson)
  final DateTime timestamp;

  final String content;

  @JsonKey(name: 'updated_at', includeIfNull: false)
  final DateTime? updatedAt;

  Message({required this.timestamp, required this.content, this.updatedAt});

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);
  Map<String, dynamic> toJson() => _$MessageToJson(this);
}
