// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'label.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LabelAdapter extends TypeAdapter<Label> {
  @override
  final int typeId = 2;

  @override
  Label read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Label(
      updatedAt: fields[4] as DateTime?,
      id: fields[0] as String,
      name: fields[1] as String,
      essayCount: fields[2] as int,
      parentId: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Label obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.essayCount)
      ..writeByte(3)
      ..write(obj.parentId)
      ..writeByte(4)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LabelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Label _$LabelFromJson(Map<String, dynamic> json) => Label(
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
      id: json['id'] as String,
      name: json['name'] as String,
      essayCount: (json['essay_count'] as num).toInt(),
      parentId: json['parent_id'] as String?,
    );

Map<String, dynamic> _$LabelToJson(Label instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'essay_count': instance.essayCount,
      'parent_id': instance.parentId,
      'updated_at': instance.updatedAt?.toIso8601String(),
    };
