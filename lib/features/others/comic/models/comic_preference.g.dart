// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comic_preference.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ComicPreferenceAdapter extends TypeAdapter<ComicPreference> {
  @override
  final int typeId = 30;

  @override
  ComicPreference read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ComicPreference(
      comicId: fields[0] as String,
      chapterIndex: fields[1] as int,
      pageIndex: fields[2] as int,
      flipReading: fields[3] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ComicPreference obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.comicId)
      ..writeByte(1)
      ..write(obj.chapterIndex)
      ..writeByte(2)
      ..write(obj.pageIndex)
      ..writeByte(3)
      ..write(obj.flipReading);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ComicPreferenceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ComicPreference _$ComicPreferenceFromJson(Map<String, dynamic> json) =>
    ComicPreference(
      comicId: json['comicId'] as String,
      chapterIndex: (json['chapterIndex'] as num).toInt(),
      pageIndex: (json['pageIndex'] as num).toInt(),
      flipReading: json['flipReading'] as bool? ?? true,
    );

Map<String, dynamic> _$ComicPreferenceToJson(ComicPreference instance) =>
    <String, dynamic>{
      'comicId': instance.comicId,
      'chapterIndex': instance.chapterIndex,
      'pageIndex': instance.pageIndex,
      'flipReading': instance.flipReading,
    };
