// ⚠️ Hive 按字段序号序列化：新增字段只能**追加**在现有 @HiveField 之后，
//    既不能插入也不能重排；@HiveType(typeId) 与既有 @HiveField 编号同样不可改动。
//    否则会破坏所有已存在的本地数据库（读旧数据时字段错位）。
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:torrid/core/api/user_data_sync.dart';
import 'package:torrid/features/booklet/models/style.dart';
import 'package:torrid/features/booklet/models/task.dart';
import 'package:torrid/core/models/mood.dart';
import 'package:torrid/core/utils/serialization.dart';
import 'package:torrid/core/utils/util.dart';

part 'record.g.dart';

@HiveType(typeId: 12)
@JsonSerializable(fieldRename: FieldRename.snake)
class Record implements SyncRow {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String styleId;

  @HiveField(2)
  @JsonKey(fromJson: dateFromJson, toJson: dateToJson)
  late final DateTime date;

  @HiveField(3)
  String message;

  @HiveField(4)
  late final Map<String, bool> taskCompletion;

  /// 心情记录 - 可选字段，兼容旧数据
  @HiveField(5)
  @MoodTypeConverter()
  MoodType? mood;

  // ↓↓↓ 同步元数据：只允许追加（见文件头注释） ↓↓↓

  @HiveField(6)
  @JsonKey(fromJson: syncTimeFromJson, toJson: syncTimeToJson)
  final DateTime? createdAt;

  @HiveField(7)
  @JsonKey(fromJson: syncTimeFromJson, toJson: syncTimeToJson)
  final DateTime? updatedAt;

  /// 墓碑：非空表示已删除，仅用于把删除动作同步出去，UI 必须过滤。
  @HiveField(8)
  @JsonKey(fromJson: syncTimeFromJson, toJson: syncTimeToJson)
  final DateTime? deletedAt;

  Record({
    required this.id,
    required this.styleId,
    required this.date,
    required this.message,
    required this.taskCompletion,
    this.mood,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  Record copyWith({
    String? id,
    String? styleId,
    DateTime? date,
    String? message,
    Map<String, bool>? taskCompletion,
    MoodType? mood,
    bool clearMood = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeleted = false,
  }) {
    return Record(
      id: id ?? this.id,
      styleId: styleId ?? this.styleId,
      date: date ?? this.date,
      message: message ?? this.message,
      taskCompletion: taskCompletion ?? this.taskCompletion,
      mood: clearMood ? null : (mood ?? this.mood),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeleted ? null : (deletedAt ?? this.deletedAt),
    );
  }

  factory Record.empty({required Style style, required DateTime date}) {
    final Map<String, bool> taskCompletion = {};
    for (Task task in style.tasks) {
      taskCompletion.addAll({task.id: false});
    }
    return Record(
      id: generateId(),
      styleId: style.id,
      date: date,
      message: "",
      taskCompletion: taskCompletion,
    );
  }

  // SyncRow：服务端的业务键是 (style_id, date)，同一业务键在本地也只应存在一行。
  @override
  String get syncStorageKey => id;

  @override
  String get syncMatchKey => '$styleId|${dateOnly(date).toIso8601String()}';

  @override
  DateTime? get syncCreatedAt => createdAt;

  @override
  DateTime? get syncUpdatedAt => updatedAt;

  @override
  DateTime? get syncDeletedAt => deletedAt;

  factory Record.fromJson(Map<String, dynamic> json) => _$RecordFromJson(json);
  Map<String, dynamic> toJson() => _$RecordToJson(this);
}
