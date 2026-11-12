// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chapter_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChapterInfo _$ChapterInfoFromJson(Map<String, dynamic> json) => ChapterInfo(
  id: json['id'] as String,
  comicId: json['comic_id'] as String,
  chapterIndex: (json['chapter_index'] as num).toInt(),
  dirName: json['dir_name'] as String,
  images:
      (json['images'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList() ??
      [],
  imageCount: (json['image_count'] as num?)?.toInt(),
);

Map<String, dynamic> _$ChapterInfoToJson(ChapterInfo instance) =>
    <String, dynamic>{
      'id': instance.id,
      'comic_id': instance.comicId,
      'chapter_index': instance.chapterIndex,
      'dir_name': instance.dirName,
      'images': instance.images,
      'image_count': instance.imageCount,
    };
