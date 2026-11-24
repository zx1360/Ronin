// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comic_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ComicInfo _$ComicInfoFromJson(Map<String, dynamic> json) => ComicInfo(
  id: json['id'] as String,
  comicName: json['title'] as String,
  coverImage: json['cover_image'] as String,
  chapterCount: (json['chapter_count'] as num).toInt(),
  imageCount: (json['image_count'] as num).toInt(),
  isPublic: json['is_public'] as bool? ?? true,
  readed: json['readed'] as bool? ?? false,
);

Map<String, dynamic> _$ComicInfoToJson(ComicInfo instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.comicName,
  'cover_image': instance.coverImage,
  'chapter_count': instance.chapterCount,
  'image_count': instance.imageCount,
  'is_public': instance.isPublic,
  'readed': instance.readed,
};
