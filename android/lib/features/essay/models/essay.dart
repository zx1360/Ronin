import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:torrid/core/models/message.dart';
import 'package:torrid/core/models/mood.dart';
import 'package:torrid/core/utils/serialization.dart';

part 'essay.g.dart';

@HiveType(typeId: 1)
@JsonSerializable(fieldRename: FieldRename.snake)
class Essay {
  @HiveField(0)
  final String id;

  @HiveField(1)
  @JsonKey(
    fromJson: dateFromJson,
    toJson: dateToJson,
  )
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

  Essay({
    required this.id,
    required this.date,
    required this.wordCount,
    required this.content,
    required this.imgs,
    required this.labels,
    required this.messages,
    this.mood,
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
    );
  }

  factory Essay.fromJson(Map<String, dynamic> json) => _$EssayFromJson(json);
  Map<String, dynamic> toJson() => _$EssayToJson(this);

  int get year => date.year;
  int get month => date.month;
}

