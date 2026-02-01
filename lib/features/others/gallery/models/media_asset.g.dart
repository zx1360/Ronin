// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_asset.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MediaAsset _$MediaAssetFromJson(Map<String, dynamic> json) => MediaAsset(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      capturedAt: DateTime.parse(json['captured_at'] as String),
      filePath: json['file_path'] as String,
      thumbPath: json['thumb_path'] as String?,
      previewPath: json['preview_path'] as String?,
      hash: json['hash'] as String,
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      mimeType: json['mime_type'] as String?,
      isDeleted: json['is_deleted'] as bool? ?? false,
      syncCount: (json['sync_count'] as num?)?.toInt() ?? 0,
      groupId: json['group_id'] as String?,
    );

Map<String, dynamic> _$MediaAssetToJson(MediaAsset instance) =>
    <String, dynamic>{
      'id': instance.id,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
      'captured_at': instance.capturedAt.toIso8601String(),
      'file_path': instance.filePath,
      'thumb_path': instance.thumbPath,
      'preview_path': instance.previewPath,
      'hash': instance.hash,
      'size_bytes': instance.sizeBytes,
      'mime_type': instance.mimeType,
      'is_deleted': instance.isDeleted,
      'sync_count': instance.syncCount,
      'group_id': instance.groupId,
    };
