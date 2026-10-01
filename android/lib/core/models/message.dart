// 随笔/打卡的中途留言（只有时间与内容两项）。
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

  Message({required this.timestamp, required this.content});

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);
  Map<String, dynamic> toJson() => _$MessageToJson(this);
}
