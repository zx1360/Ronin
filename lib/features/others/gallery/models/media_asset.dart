/// 媒体资源模型 - 对应服务端 media_assets 表
library;

import 'package:json_annotation/json_annotation.dart';

part 'media_asset.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class MediaAsset {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime capturedAt;

  /// 文件相对路径 (服务端路径或本地路径)
  final String filePath;
  final String? thumbPath;
  final String? previewPath;

  /// SHA-256 哈希 (base64编码)
  final String hash;
  @JsonKey(defaultValue: 0)
  final int sizeBytes;
  final String? mimeType;
  @JsonKey(defaultValue: false)
  final bool isDeleted;
  @JsonKey(defaultValue: 0)
  final int syncCount;

  /// 捆绑组主文件ID
  final String? groupId;
  /// 对该媒体文件的留言
  final String? message;

  const MediaAsset({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.capturedAt,
    required this.filePath,
    this.thumbPath,
    this.previewPath,
    required this.hash,
    this.sizeBytes = 0,
    this.mimeType,
    this.isDeleted = false,
    this.syncCount = 0,
    this.groupId,
    this.message,
  });

  MediaAsset copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? capturedAt,
    String? filePath,
    String? thumbPath,
    String? previewPath,
    String? hash,
    int? sizeBytes,
    String? mimeType,
    bool? isDeleted,
    int? syncCount,
    String? groupId,
    bool clearGroupId = false,
    String? message,
    bool clearMessage = false,
  }) {
    return MediaAsset(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      capturedAt: capturedAt ?? this.capturedAt,
      filePath: filePath ?? this.filePath,
      thumbPath: thumbPath ?? this.thumbPath,
      previewPath: previewPath ?? this.previewPath,
      hash: hash ?? this.hash,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      mimeType: mimeType ?? this.mimeType,
      isDeleted: isDeleted ?? this.isDeleted,
      syncCount: syncCount ?? this.syncCount,
      groupId: clearGroupId ? null : (groupId ?? this.groupId),
      message: clearMessage ? null : (message ?? this.message),
    );
  }

  /// 是否为图片类型
  bool get isImage =>
      mimeType?.startsWith('image/') ?? _isImageByPath(filePath);

  /// 是否为视频类型
  bool get isVideo =>
      mimeType?.startsWith('video/') ?? _isVideoByPath(filePath);

  /// 是否为组主文件 (有其他文件绑定到此文件)
  bool get isGroupLead => groupId == null;

  /// 是否为组成员 (绑定到其他文件)
  bool get isGroupMember => groupId != null;

  static bool _isImageByPath(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext);
  }

  static bool _isVideoByPath(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ['mp4', 'avi', 'mov', 'mkv', 'webm', 'flv'].contains(ext);
  }

  factory MediaAsset.fromJson(Map<String, dynamic> json) =>
      _$MediaAssetFromJson(json);

  Map<String, dynamic> toJson() => _$MediaAssetToJson(this);

  /// 转换为数据库 Map
  Map<String, dynamic> toDbMap() => {
        'id': id,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'captured_at': capturedAt.toIso8601String(),
        'file_path': filePath,
        'thumb_path': thumbPath,
        'preview_path': previewPath,
        'hash': hash,
        'size_bytes': sizeBytes,
        'mime_type': mimeType,
        'is_deleted': isDeleted ? 1 : 0,
        'sync_count': syncCount,
        'group_id': groupId,
        'message': message,
      };

  factory MediaAsset.fromDbMap(Map<String, dynamic> map) => MediaAsset(
        id: map['id'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
        capturedAt: DateTime.parse(map['captured_at'] as String),
        filePath: map['file_path'] as String,
        thumbPath: map['thumb_path'] as String?,
        previewPath: map['preview_path'] as String?,
        hash: map['hash'] as String,
        sizeBytes: map['size_bytes'] as int? ?? 0,
        mimeType: map['mime_type'] as String?,
        isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
        syncCount: map['sync_count'] as int? ?? 0,
        groupId: map['group_id'] as String?,
        message: map['message'] as String?,
      );
}
