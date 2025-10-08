// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comic_progress.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ComicProgressAdapter extends TypeAdapter<ComicProgress> {
  @override
  final int typeId = 30;

  @override
  ComicProgress read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ComicProgress(
      name: fields[0] as String,
      chapterIndex: fields[1] as int,
      pageIndex: fields[2] as int,
    );
  }

  @override
  void write(BinaryWriter writer, ComicProgress obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.chapterIndex)
      ..writeByte(2)
      ..write(obj.pageIndex);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ComicProgressAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
