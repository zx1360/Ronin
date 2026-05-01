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

  const Tag({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.name,
    this.parentId,
    this.fullPath,
  });

  Tag copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? name,
    String? parentId,
    String? fullPath,
    bool clearParentId = false,
  }) {
    return Tag(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      name: name ?? this.name,
      parentId: clearParentId ? null : (parentId ?? this.parentId),
      fullPath: fullPath ?? this.fullPath,
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
      };

  factory Tag.fromDbMap(Map<String, dynamic> map) => Tag(
        id: map['id'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
        name: map['name'] as String,
        parentId: map['parent_id'] as String?,
        fullPath: map['full_path'] as String?,
      );
}
