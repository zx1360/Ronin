// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mood.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MoodTypeAdapter extends TypeAdapter<MoodType> {
  @override
  final int typeId = 8;

  @override
  MoodType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return MoodType.happy;
      case 1:
        return MoodType.calm;
      case 2:
        return MoodType.sad;
      case 3:
        return MoodType.angry;
      case 4:
        return MoodType.tired;
      default:
        return MoodType.happy;
    }
  }

  @override
  void write(BinaryWriter writer, MoodType obj) {
    switch (obj) {
      case MoodType.happy:
        writer.writeByte(0);
        break;
      case MoodType.calm:
        writer.writeByte(1);
        break;
      case MoodType.sad:
        writer.writeByte(2);
        break;
      case MoodType.angry:
        writer.writeByte(3);
        break;
      case MoodType.tired:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MoodTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
