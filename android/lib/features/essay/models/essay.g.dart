// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'essay.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Essay _$EssayFromJson(Map<String, dynamic> json) => Essay(
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
  labelsUpdatedAt: json['labels_updated_at'] == null
      ? null
      : DateTime.parse(json['labels_updated_at'] as String),
  id: json['id'] as String,
  date: dateTimeFromJson(json['date'] as String),
  wordCount: (json['word_count'] as num).toInt(),
  content: json['content'] as String,
  imgs: (json['imgs'] as List<dynamic>).map((e) => e as String).toList(),
  labels: (json['labels'] as List<dynamic>).map((e) => e as String).toList(),
  messages:
      (json['messages'] as List<dynamic>?)
          ?.map((e) => Message.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  mood: const MoodTypeConverter().fromJson(json['mood'] as String?),
  title: json['title'] as String? ?? '',
);

Map<String, dynamic> _$EssayToJson(Essay instance) => <String, dynamic>{
  'id': instance.id,
  'date': dateTimeToJson(instance.date),
  'word_count': instance.wordCount,
  'content': instance.content,
  'imgs': instance.imgs,
  'labels': instance.labels,
  'messages': instance.messages,
  'mood': const MoodTypeConverter().toJson(instance.mood),
  'title': instance.title,
  'updated_at': instance.updatedAt?.toIso8601String(),
  'created_at': instance.createdAt?.toIso8601String(),
  'labels_updated_at': instance.labelsUpdatedAt?.toIso8601String(),
};
