import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:torrid/core/utils/util.dart';

part 'label.g.dart';

@HiveType(typeId: 2)
@JsonSerializable(fieldRename: FieldRename.snake)
class Label {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final int essayCount;

  @HiveField(3)
  final String? parentId;

  static const hiddenId = '00000000-0000-4000-8000-000000000001';

  @HiveField(4)
  final DateTime? updatedAt;

  Label({
    this.updatedAt,
    required this.id,
    required this.name,
    required this.essayCount,
    this.parentId,
  });

  bool get isHiddenRoot => id == hiddenId || (name == '隐藏' && parentId == null);

  Label copyWith({
    DateTime? updatedAt,
    String? id,
    String? name,
    int? essayCount,
    String? parentId,
    bool clearParent = false,
  }) {
    return Label(
      updatedAt: updatedAt ?? this.updatedAt,
      id: id ?? this.id,
      name: name ?? this.name,
      essayCount: essayCount ?? this.essayCount,
      parentId: clearParent ? null : (parentId ?? this.parentId),
    );
  }

  factory Label.newOne(String name, {String? parentId}) {
    return Label(
      id: generateId(),
      name: name,
      essayCount: 0,
      parentId: parentId,
    );
  }

  factory Label.hidden() => Label(id: hiddenId, name: '隐藏', essayCount: 0);

  // (反)序列化
  factory Label.fromJson(Map<String, dynamic> json) => _$LabelFromJson(json);
  Map<String, dynamic> toJson() => _$LabelToJson(this);
}
