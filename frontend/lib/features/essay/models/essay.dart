// ⚠️ Hive 按字段序号序列化：新增字段只能**追加**在现有 @HiveField 之后，
//    既不能插入也不能重排；@HiveType(typeId) 与既有 @HiveField 编号同样不可改动。
//    否则会破坏所有已存在的本地数据库（读旧数据时字段错位）。
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:torrid/core/api/user_data_sync.dart';
import 'package:torrid/core/models/message.dart';
import 'package:torrid/core/models/mood.dart';
import 'package:torrid/core/utils/serialization.dart';

part 'essay.g.dart';

@HiveType(typeId: 1)
@JsonSerializable(fieldRename: FieldRename.snake)
class Essay implements SyncRow {
  @HiveField(0)
  final String id;

  @HiveField(1)
  @JsonKey(fromJson: dateTimeFromJson, toJson: dateTimeToJson)
  final DateTime date;

  @HiveField(2)
  final int wordCount;

  @HiveField(3)
  final String content;

  @HiveField(4)
  final List<String> imgs;

  @HiveField(5)
  final List<String> labels;

  @HiveField(6)
  @JsonKey(defaultValue: [])
  final List<Message> messages;

  /// 心情记录 - 可选字段，兼容旧数据
  @HiveField(7)
  @MoodTypeConverter()
  final MoodType? mood;

  // ↓↓↓ 同步元数据：只允许追加（见文件头注释） ↓↓↓

  /// 首次写入时间（服务端可能缺省）。
  @HiveField(8)
  @JsonKey(fromJson: syncTimeFromJson, toJson: syncTimeToJson)
  final DateTime? createdAt;

  /// 最后修改时间，逐行合并的比较依据。
  @HiveField(9)
  @JsonKey(fromJson: syncTimeFromJson, toJson: syncTimeToJson)
  final DateTime? updatedAt;

  /// 墓碑：非空表示已删除，仅用于把删除动作同步出去，UI 必须过滤。
  @HiveField(10)
  @JsonKey(fromJson: syncTimeFromJson, toJson: syncTimeToJson)
  final DateTime? deletedAt;

  Essay({
    required this.id,
    required this.date,
    required this.wordCount,
    required this.content,
    required this.imgs,
    required this.labels,
    required this.messages,
    this.mood,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  Essay copyWith({
    String? id,
    DateTime? date,
    int? wordCount,
    String? content,
    List<String>? imgs,
    List<String>? labels,
    List<Message>? messages,
    MoodType? mood,
    bool clearMood = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeleted = false,
  }) {
    return Essay(
      id: id ?? this.id,
      date: date ?? this.date,
      wordCount: wordCount ?? this.wordCount,
      content: content ?? this.content,
      imgs: imgs ?? this.imgs,
      labels: labels ?? this.labels,
      messages: messages ?? this.messages,
      mood: clearMood ? null : (mood ?? this.mood),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeleted ? null : (deletedAt ?? this.deletedAt),
    );
  }

  // SyncRow：随笔在两端都以 id 为键。
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

  factory Essay.fromJson(Map<String, dynamic> json) => _$EssayFromJson(json);
  Map<String, dynamic> toJson() => _$EssayToJson(this);

  int get year => date.year;
  int get month => date.month;
}
