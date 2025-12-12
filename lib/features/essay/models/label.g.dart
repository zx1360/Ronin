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
    );
  }

  @override
  void write(BinaryWriter writer, Label obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.essayCount);
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
    );

Map<String, dynamic> _$LabelToJson(Label instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'essay_count': instance.essayCount,
    };
