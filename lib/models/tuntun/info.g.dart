// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'info.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InfoAdapter extends TypeAdapter<Info> {
  @override
  final int typeId = 20;

  @override
  Info read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Info(
      id: fields[0] as String,
      filePath: fields[1] as String,
      ext: fields[2] as String,
      fileSize: fields[3] as int,
      createTime: fields[4] as int,
      modifyTime: fields[5] as int,
      mimeType: fields[6] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Info obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.filePath)
      ..writeByte(2)
      ..write(obj.ext)
      ..writeByte(3)
      ..write(obj.fileSize)
      ..writeByte(4)
      ..write(obj.createTime)
      ..writeByte(5)
      ..write(obj.modifyTime)
      ..writeByte(6)
      ..write(obj.mimeType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InfoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
