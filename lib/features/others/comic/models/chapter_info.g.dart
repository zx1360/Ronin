// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chapter_info.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ChapterInfoAdapter extends TypeAdapter<ChapterInfo> {
  @override
  final int typeId = 32;

  @override
  ChapterInfo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChapterInfo(
      id: fields[0] as String,
      comicId: fields[1] as String,
      chapterIndex: fields[2] as int,
      dirName: fields[3] as String,
      images: (fields[4] as List)
          .map((dynamic e) => (e as Map).cast<String, dynamic>())
          .toList(),
    );
  }

  @override
  void write(BinaryWriter writer, ChapterInfo obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.comicId)
      ..writeByte(2)
      ..write(obj.chapterIndex)
      ..writeByte(3)
      ..write(obj.dirName)
      ..writeByte(4)
      ..write(obj.images);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChapterInfoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChapterInfo _$ChapterInfoFromJson(Map<String, dynamic> json) => ChapterInfo(
      id: json['id'] as String,
      comicId: json['comicId'] as String,
      chapterIndex: (json['chapterIndex'] as num).toInt(),
      dirName: json['dirName'] as String,
      images: (json['images'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList(),
    );

Map<String, dynamic> _$ChapterInfoToJson(ChapterInfo instance) =>
    <String, dynamic>{
      'id': instance.id,
      'comicId': instance.comicId,
      'chapterIndex': instance.chapterIndex,
      'dirName': instance.dirName,
      'images': instance.images,
    };
