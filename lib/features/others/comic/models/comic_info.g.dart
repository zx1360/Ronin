// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comic_info.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ComicInfoAdapter extends TypeAdapter<ComicInfo> {
  @override
  final int typeId = 31;

  @override
  ComicInfo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ComicInfo(
      id: fields[0] as String,
      comicName: fields[1] as String,
      coverImage: fields[2] as String,
      chapterCount: fields[3] as int,
      imageCount: fields[4] as int,
    );
  }

  @override
  void write(BinaryWriter writer, ComicInfo obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.comicName)
      ..writeByte(2)
      ..write(obj.coverImage)
      ..writeByte(3)
      ..write(obj.chapterCount)
      ..writeByte(4)
      ..write(obj.imageCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ComicInfoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ComicInfo _$ComicInfoFromJson(Map<String, dynamic> json) => ComicInfo(
      id: json['id'] as String,
      comicName: json['comic_name'] as String,
      coverImage: json['cover_image'] as String,
      chapterCount: (json['chapter_count'] as num).toInt(),
      imageCount: (json['image_count'] as num).toInt(),
    );

Map<String, dynamic> _$ComicInfoToJson(ComicInfo instance) => <String, dynamic>{
      'id': instance.id,
      'comic_name': instance.comicName,
      'cover_image': instance.coverImage,
      'chapter_count': instance.chapterCount,
      'image_count': instance.imageCount,
    };
