// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'style.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Style _$StyleFromJson(Map<String, dynamic> json) => Style(
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
  id: json['id'] as String,
  startDate: dateFromJson(json['start_date'] as String),
  validCheckIn: (json['valid_check_in'] as num).toInt(),
  fullyDone: (json['fully_done'] as num).toInt(),
  longestStreak: (json['longest_streak'] as num).toInt(),
  longestFullyStreak: (json['longest_fully_streak'] as num).toInt(),
  tasks: (json['tasks'] as List<dynamic>)
      .map((e) => Task.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$StyleToJson(Style instance) => <String, dynamic>{
  'id': instance.id,
  'start_date': dateToJson(instance.startDate),
  'valid_check_in': instance.validCheckIn,
  'fully_done': instance.fullyDone,
  'longest_streak': instance.longestStreak,
  'longest_fully_streak': instance.longestFullyStreak,
  'tasks': instance.tasks,
  'updated_at': instance.updatedAt?.toIso8601String(),
};
