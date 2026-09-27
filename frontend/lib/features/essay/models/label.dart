// ⚠️ Hive 按字段序号序列化：新增字段只能**追加**在现有 @HiveField 之后，
//    既不能插入也不能重排；@HiveType(typeId) 与既有 @HiveField 编号同样不可改动。
//    否则会破坏所有已存在的本地数据库（读旧数据时字段错位）。
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:torrid/core/api/user_data_sync.dart';
import 'package:torrid/core/utils/util.dart';

part 'label.g.dart';

@HiveType(typeId: 2)
@JsonSerializable(fieldRename: FieldRename.snake)
class Label implements SyncRow {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final int essayCount;

  // ↓↓↓ 同步元数据：只允许追加（见文件头注释） ↓↓↓

  @HiveField(3)
  @JsonKey(fromJson: syncTimeFromJson, toJson: syncTimeToJson)
  final DateTime? createdAt;

  @HiveField(4)
  @JsonKey(fromJson: syncTimeFromJson, toJson: syncTimeToJson)
  final DateTime? updatedAt;

  /// 墓碑：非空表示已删除，仅用于把删除动作同步出去，UI 必须过滤。
  @HiveField(5)
  @JsonKey(fromJson: syncTimeFromJson, toJson: syncTimeToJson)
  final DateTime? deletedAt;

  Label({
    required this.id,
    required this.name,
    required this.essayCount,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  Label copyWith({
    String? id,
    String? name,
    int? essayCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeleted = false,
  }) {
    return Label(
      id: id ?? this.id,
      name: name ?? this.name,
      essayCount: essayCount ?? this.essayCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeleted ? null : (deletedAt ?? this.deletedAt),
    );
  }

  factory Label.newOne(String name) {
    final now = DateTime.now();
    return Label(
      id: generateId(),
      name: name,
      essayCount: 0,
      createdAt: now,
      updatedAt: now,
    );
  }

  // SyncRow：标签在两端都以 id 为键。
  @override
  String get syncStorageKey => id;

  @override
  String get syncMatchKey => id;

  @override
  DateTime? get syncCreatedAt => createdAt;

  @override
  DateTime? get syncUpdatedAt => updatedAt;

  @override
  DateTime? get syncDeletedAt => deletedAt;

  // (反)序列化
  factory Label.fromJson(Map<String, dynamic> json)=> _$LabelFromJson(json);
  Map<String, dynamic> toJson() => _$LabelToJson(this);
}
