// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'style.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StyleAdapter extends TypeAdapter<Style> {
  @override
  final int typeId = 10;

  @override
  Style read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Style(
      id: fields[0] as String,
      startDate: fields[1] as DateTime,
      validCheckIn: fields[2] as int,
      fullyDone: fields[3] as int,
      longestStreak: fields[4] as int,
      longestFullyStreak: fields[5] as int,
      tasks: (fields[6] as List).cast<Task>(),
      createdAt: fields[7] as DateTime?,
      updatedAt: fields[8] as DateTime?,
      deletedAt: fields[9] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Style obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.startDate)
      ..writeByte(2)
      ..write(obj.validCheckIn)
      ..writeByte(3)
      ..write(obj.fullyDone)
      ..writeByte(4)
      ..write(obj.longestStreak)
      ..writeByte(5)
      ..write(obj.longestFullyStreak)
      ..writeByte(6)
      ..write(obj.tasks)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.updatedAt)
      ..writeByte(9)
      ..write(obj.deletedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StyleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Style _$StyleFromJson(Map<String, dynamic> json) => Style(
      id: json['id'] as String,
      startDate: dateFromJson(json['start_date'] as String),
      validCheckIn: (json['valid_check_in'] as num).toInt(),
      fullyDone: (json['fully_done'] as num).toInt(),
      longestStreak: (json['longest_streak'] as num).toInt(),
      longestFullyStreak: (json['longest_fully_streak'] as num).toInt(),
      tasks: (json['tasks'] as List<dynamic>)
          .map((e) => Task.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: syncTimeFromJson(json['created_at'] as String?),
      updatedAt: syncTimeFromJson(json['updated_at'] as String?),
      deletedAt: syncTimeFromJson(json['deleted_at'] as String?),
    );

Map<String, dynamic> _$StyleToJson(Style instance) => <String, dynamic>{
      'id': instance.id,
      'start_date': dateToJson(instance.startDate),
      'valid_check_in': instance.validCheckIn,
      'fully_done': instance.fullyDone,
      'longest_streak': instance.longestStreak,
      'longest_fully_streak': instance.longestFullyStreak,
      'tasks': instance.tasks,
      'created_at': syncTimeToJson(instance.createdAt),
      'updated_at': syncTimeToJson(instance.updatedAt),
      'deleted_at': syncTimeToJson(instance.deletedAt),
    };
