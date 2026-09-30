// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'review_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ReviewPresetAdapter extends TypeAdapter<ReviewPreset> {
  @override
  final int typeId = 43;

  @override
  ReviewPreset read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReviewPreset(
      id: fields[0] as String,
      name: fields[1] as String,
      role: fields[2] as String,
      tone: fields[3] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ReviewPreset obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.role)
      ..writeByte(3)
      ..write(obj.tone);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReviewPresetAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ReviewRecordAdapter extends TypeAdapter<ReviewRecord> {
  @override
  final int typeId = 44;

  @override
  ReviewRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReviewRecord(
      id: fields[0] as String,
      presetName: fields[1] as String,
      span: fields[2] as String,
      createdAt: fields[3] as DateTime,
      content: fields[4] as String,
      stats: fields[5] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ReviewRecord obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.presetName)
      ..writeByte(2)
      ..write(obj.span)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.content)
      ..writeByte(5)
      ..write(obj.stats);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReviewRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
