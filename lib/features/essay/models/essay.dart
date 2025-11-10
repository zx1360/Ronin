import 'package:hive/hive.dart';
import 'package:torrid/shared/models/message.dart';

part 'essay.g.dart';

@HiveType(typeId: 1)
class Essay {
  @HiveField(0)
  final String id;

  @HiveField(1)
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
  final List<Message> messages;

  Essay({
    required this.id,
    required this.date,
    required this.wordCount,
    required this.content,
    required this.imgs,
    required this.labels,
    required this.messages,
  });

  Essay copyWith({
  String? id,
  DateTime? date,
  int? wordCount,
  String? content,
  List<String>? imgs,
  List<String>? labels,
  List<Message>? messages,
}) {
  return Essay(
    id: id ?? this.id,
    date: date ?? this.date,
    wordCount: wordCount ?? this.wordCount,
    content: content ?? this.content,
    imgs: imgs ?? this.imgs,
    labels: labels ?? this.labels,
    messages: messages ?? this.messages,
  );
}

  factory Essay.fromJson(Map<String, dynamic> json) {
    return Essay(
      id: json['id'],
      date: DateTime.parse(json['date']),
      wordCount: json['wordCount'],
      content: json['content'],
      imgs: List<String>.from(json['imgs']),
      labels: List<String>.from(json['labels']),
      messages: json['messages'] != null
          ? (json['messages'] as List)
                .map((item) => Message.fromJson(item))
                .toList()
          : [],
    );
  }
  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "date": date.toLocal().toString().split('.').first,
      "wordCount": wordCount,
      "content": content,
      "imgs": imgs,
      "labels": labels,
      "messages": messages.map((item) => item.toJson()).toList(),
    };
  }

  int get year => date.year;
  int get month => date.month;
}
