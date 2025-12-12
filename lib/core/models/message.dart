// 追加留言的数据类, 对于以前的日记/大任务的中途留言. 似乎也只需要时间和内容两项.
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:torrid/core/utils/serialization.dart';

part 'message.g.dart';

@HiveType(typeId: 9)
@JsonSerializable(fieldRename: FieldRename.none)
class Message {
  @HiveField(0)
  @JsonKey(fromJson: dateFromJson, toJson: dateToJson)
  final DateTime timestamp;

  @HiveField(1)
  final String content;

  Message({required this.timestamp, required this.content});

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);
  Map<String, dynamic> toJson() => _$MessageToJson(this);
}
