// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RecordAdapter extends TypeAdapter<Record> {
  @override
  final int typeId = 12;

  @override
  Record read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Record(
      id: fields[0] as String,
      styleId: fields[1] as String,
      date: fields[2] as DateTime,
      message: fields[3] as String,
      taskCompletion: (fields[4] as Map).cast<String, bool>(),
      mood: fields[5] as MoodType?,
    );
  }

  @override
  void write(BinaryWriter writer, Record obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.styleId)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.message)
      ..writeByte(4)
      ..write(obj.taskCompletion)
      ..writeByte(5)
      ..write(obj.mood);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Record _$RecordFromJson(Map<String, dynamic> json) => Record(
      id: json['id'] as String,
      styleId: json['style_id'] as String,
      date: DateTime.parse(json['date'] as String),
      message: json['message'] as String,
      taskCompletion: Map<String, bool>.from(json['task_completion'] as Map),
      mood: const MoodTypeConverter().fromJson(json['mood'] as String?),
    );

Map<String, dynamic> _$RecordToJson(Record instance) => <String, dynamic>{
      'id': instance.id,
      'style_id': instance.styleId,
      'date': instance.date.toIso8601String(),
      'message': instance.message,
      'task_completion': instance.taskCompletion,
      'mood': const MoodTypeConverter().toJson(instance.mood),
    };
