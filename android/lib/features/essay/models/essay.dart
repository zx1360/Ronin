import 'package:json_annotation/json_annotation.dart';
import 'package:torrid/core/models/message.dart';
import 'package:torrid/core/models/mood.dart';
import 'package:torrid/core/utils/serialization.dart';

part 'essay.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class Essay {
  final String id;

  @JsonKey(fromJson: dateTimeFromJson, toJson: dateTimeToJson)
  final DateTime date;

  final int wordCount;

  final String content;

  final List<String> imgs;

  final List<String> labels;

  @JsonKey(defaultValue: [])
  final List<Message> messages;

  @MoodTypeConverter()
  final MoodType? mood;

  @JsonKey(defaultValue: '')
  final String title;

  final DateTime? updatedAt;

  final DateTime? createdAt;

  final DateTime? labelsUpdatedAt;

  Essay({
    this.updatedAt,
    this.createdAt,
    this.labelsUpdatedAt,
    required this.id,
    required this.date,
    required this.wordCount,
    required this.content,
    required this.imgs,
    required this.labels,
    required this.messages,
    this.mood,
    this.title = '',
  });

  Essay copyWith({
    DateTime? updatedAt,
    DateTime? createdAt,
    DateTime? labelsUpdatedAt,
    String? id,
    DateTime? date,
    int? wordCount,
    String? content,
    List<String>? imgs,
    List<String>? labels,
    List<Message>? messages,
    MoodType? mood,
    bool clearMood = false,
    String? title,
  }) {
    return Essay(
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
      labelsUpdatedAt: labelsUpdatedAt ?? this.labelsUpdatedAt,
      id: id ?? this.id,
      date: date ?? this.date,
      wordCount: wordCount ?? this.wordCount,
      content: content ?? this.content,
      imgs: imgs ?? this.imgs,
      labels: labels ?? this.labels,
      messages: messages ?? this.messages,
      mood: clearMood ? null : (mood ?? this.mood),
      title: title ?? this.title,
    );
  }

  factory Essay.fromJson(Map<String, dynamic> json) => _$EssayFromJson(json);
  Map<String, dynamic> toJson() => _$EssayToJson(this);

  int get year => date.year;
  int get month => date.month;

  int get messageWordCount =>
      messages.fold(0, (sum, message) => sum + message.content.trim().length);

  int get totalWordCount => wordCount + messageWordCount;

  String get wordCountText {
    final extra = messageWordCount;
    return extra == 0 ? '$wordCount字' : '$wordCount字(+$extra字)';
  }
}
