import 'package:hive/hive.dart';
import 'package:torrid/shared/models/message.dart';
import 'package:torrid/shared/utils/util.dart';

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
    this.messages = const [],
  });

  factory Essay.fromJson(Map<String, dynamic> json) {
    return Essay(
      id: (json['id'] as String).length < 17 ? Util.generateId() : json['id'],
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
