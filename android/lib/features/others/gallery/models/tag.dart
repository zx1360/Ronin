/// 标签模型 - 对应服务端 tags 表 (树状结构)
library;

import 'package:json_annotation/json_annotation.dart';

part 'tag.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class Tag {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String name;

  /// 父标签ID, 根节点为 null
  final String? parentId;

  /// 完整路径 (如 "Family/2023/Xmas")
  final String? fullPath;

  /// 快捷标签标记 (服务端持久化, 随标签数据一并下载)
  @JsonKey(defaultValue: false)
  final bool isFavorite;

  /// 直接关联的未删除媒体数 (仅 GET /tags 统计, 本地缓存不保存)
  @JsonKey(defaultValue: 0)
  final int mediaCount;

  const Tag({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.name,
    this.parentId,
    this.fullPath,
    this.isFavorite = false,
    this.mediaCount = 0,
  });

  Tag copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? name,
    String? parentId,
    String? fullPath,
    bool? isFavorite,
    int? mediaCount,
    bool clearParentId = false,
  }) {
    return Tag(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      name: name ?? this.name,
      parentId: clearParentId ? null : (parentId ?? this.parentId),
      fullPath: fullPath ?? this.fullPath,
      isFavorite: isFavorite ?? this.isFavorite,
      mediaCount: mediaCount ?? this.mediaCount,
    );
  }

  /// 是否为根标签
  bool get isRoot => parentId == null;

  /// 层级深度 (根据 fullPath 计算)
  int get depth => fullPath?.split('/').length ?? 1;

  factory Tag.fromJson(Map<String, dynamic> json) => _$TagFromJson(json);

  Map<String, dynamic> toJson() => _$TagToJson(this);

  /// 转换为数据库 Map
  Map<String, dynamic> toDbMap() => {
        'id': id,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'name': name,
        'parent_id': parentId,
        'full_path': fullPath,
        'is_favorite': isFavorite ? 1 : 0,
      };

  factory Tag.fromDbMap(Map<String, dynamic> map) => Tag(
        id: map['id'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
        name: map['name'] as String,
        parentId: map['parent_id'] as String?,
        fullPath: map['full_path'] as String?,
        isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
      );
}
