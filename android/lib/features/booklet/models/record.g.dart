// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'record.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Record _$RecordFromJson(Map<String, dynamic> json) => Record(
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
  id: json['id'] as String,
  styleId: json['style_id'] as String,
  date: dateFromJson(json['date'] as String),
  message: json['message'] as String,
  taskCompletion: Map<String, bool>.from(json['task_completion'] as Map),
  mood: const MoodTypeConverter().fromJson(json['mood'] as String?),
);

Map<String, dynamic> _$RecordToJson(Record instance) => <String, dynamic>{
  'id': instance.id,
  'style_id': instance.styleId,
  'date': dateToJson(instance.date),
  'message': instance.message,
  'task_completion': instance.taskCompletion,
  'mood': const MoodTypeConverter().toJson(instance.mood),
  'updated_at': instance.updatedAt?.toIso8601String(),
};
