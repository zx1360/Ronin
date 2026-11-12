// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Message _$MessageFromJson(Map<String, dynamic> json) => Message(
  timestamp: dateTimeFromJson(json['timestamp'] as String),
  content: json['content'] as String,
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$MessageToJson(Message instance) => <String, dynamic>{
  'timestamp': dateTimeToJson(instance.timestamp),
  'content': instance.content,
  'updated_at': ?instance.updatedAt?.toIso8601String(),
};
