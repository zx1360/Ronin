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
      id: fields[0] as String,
      name: fields[1] as String,
      essayCount: fields[2] as int,
      createdAt: fields[3] as DateTime?,
      updatedAt: fields[4] as DateTime?,
      deletedAt: fields[5] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Label obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.essayCount)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.updatedAt)
      ..writeByte(5)
      ..write(obj.deletedAt);
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
      id: json['id'] as String,
      name: json['name'] as String,
      essayCount: (json['essay_count'] as num).toInt(),
      createdAt: syncTimeFromJson(json['created_at'] as String?),
      updatedAt: syncTimeFromJson(json['updated_at'] as String?),
      deletedAt: syncTimeFromJson(json['deleted_at'] as String?),
    );

Map<String, dynamic> _$LabelToJson(Label instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'essay_count': instance.essayCount,
      'created_at': syncTimeToJson(instance.createdAt),
      'updated_at': syncTimeToJson(instance.updatedAt),
      'deleted_at': syncTimeToJson(instance.deletedAt),
    };
