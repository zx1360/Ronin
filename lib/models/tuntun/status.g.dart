// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'status.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StatusAdapter extends TypeAdapter<Status> {
  @override
  final int typeId = 21;

  @override
  Status read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Status(
      mediaId: fields[0] as String,
      tags: (fields[1] as List).cast<String>(),
      bundleWith: (fields[2] as List).cast<String>(),
      isMarkedDeleted: fields[3] as bool,
      messages: (fields[4] as List).cast<Message>(),
    );
  }

  @override
  void write(BinaryWriter writer, Status obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.mediaId)
      ..writeByte(1)
      ..write(obj.tags)
      ..writeByte(2)
      ..write(obj.bundleWith)
      ..writeByte(3)
      ..write(obj.isMarkedDeleted)
      ..writeByte(4)
      ..write(obj.messages);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
