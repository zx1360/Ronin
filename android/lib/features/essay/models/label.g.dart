// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'label.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Label _$LabelFromJson(Map<String, dynamic> json) => Label(
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
  id: json['id'] as String,
  name: json['name'] as String,
  essayCount: (json['essay_count'] as num?)?.toInt() ?? 0,
  parentId: json['parent_id'] as String?,
);

Map<String, dynamic> _$LabelToJson(Label instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'essay_count': instance.essayCount,
  'parent_id': instance.parentId,
  'updated_at': instance.updatedAt?.toIso8601String(),
};
