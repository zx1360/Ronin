// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_batch.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BatchResponse _$BatchResponseFromJson(Map<String, dynamic> json) =>
    BatchResponse(
      medias: (json['media_assets'] as List<dynamic>?)
              ?.map((e) => MediaAsset.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => Tag.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      links: (json['media_tag_links'] as List<dynamic>?)
              ?.map((e) => MediaTagLink.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );

Map<String, dynamic> _$BatchResponseToJson(BatchResponse instance) =>
    <String, dynamic>{
      'media_assets': instance.medias,
      'tags': instance.tags,
      'media_tag_links': instance.links,
    };
