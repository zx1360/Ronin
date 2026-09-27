// ⚠️ Hive 按字段序号序列化：新增字段只能**追加**在现有 @HiveField 之后，
//    既不能插入也不能重排；@HiveType(typeId) 与既有 @HiveField 编号同样不可改动。
//    否则会破坏所有已存在的本地数据库（读旧数据时字段错位）。
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:torrid/core/api/user_data_sync.dart';
import 'package:torrid/core/utils/serialization.dart';
import 'package:torrid/features/booklet/models/task.dart';
import 'package:torrid/core/utils/util.dart';

part 'style.g.dart';

@HiveType(typeId: 10)
@JsonSerializable(fieldRename: FieldRename.snake)
class Style implements SyncRow {
  @HiveField(0)
  final String id;

  @HiveField(1)
  @JsonKey(
    fromJson: dateFromJson,
    toJson: dateToJson,
  )
  final DateTime startDate;

  @HiveField(2)
  final int validCheckIn;

  @HiveField(3)
  final int fullyDone;

  @HiveField(4)
  final int longestStreak;

  @HiveField(5)
  final int longestFullyStreak;

  @HiveField(6)
  final List<Task> tasks;

  // ↓↓↓ 同步元数据：只允许追加（见文件头注释） ↓↓↓

  @HiveField(7)
  @JsonKey(fromJson: syncTimeFromJson, toJson: syncTimeToJson)
  final DateTime? createdAt;

  @HiveField(8)
  @JsonKey(fromJson: syncTimeFromJson, toJson: syncTimeToJson)
  final DateTime? updatedAt;

  /// 墓碑：非空表示已删除，仅用于把删除动作同步出去，UI 必须过滤。
  @HiveField(9)
  @JsonKey(fromJson: syncTimeFromJson, toJson: syncTimeToJson)
  final DateTime? deletedAt;

  Style({
    required this.id,
    required this.startDate,
    required this.validCheckIn,
    required this.fullyDone,
    required this.longestStreak,
    required this.longestFullyStreak,
    required this.tasks,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  Style copyWith({
    String? id,
    DateTime? startDate,
    int? validCheckIn,
    int? fullyDone,
    int? longestStreak,
    int? longestFullyStreak,
    List<Task>? tasks,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeleted = false,
  }) {
    return Style(
      id: id ?? this.id,
      startDate: startDate ?? this.startDate,
      validCheckIn: validCheckIn ?? this.validCheckIn,
      fullyDone: fullyDone ?? this.fullyDone,
      longestStreak: longestStreak ?? this.longestStreak,
      longestFullyStreak: longestFullyStreak ?? this.longestFullyStreak,
      tasks: tasks ?? this.tasks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeleted ? null : (deletedAt ?? this.deletedAt),
    );
  }

  factory Style.newOne(DateTime date, List<Task> tasks) {
    return Style(
      id: generateId(),
      startDate: date,
      validCheckIn: 0,
      fullyDone: 0,
      longestStreak: 0,
      longestFullyStreak: 0,
      tasks: tasks,
    );
  }

  // SyncRow：打卡样式在两端都以 id 为键。
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

  factory Style.fromJson(Map<String, dynamic> json) => _$StyleFromJson(json);
  Map<String, dynamic> toJson() => _$StyleToJson(this);
}
