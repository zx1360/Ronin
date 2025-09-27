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
    );
  }

  @override
  void write(BinaryWriter writer, Style obj) {
    writer
      ..writeByte(7)
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
      ..write(obj.tasks);
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
