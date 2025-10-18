// 追加留言的数据类, 对于以前的日记/大任务的中途留言. 似乎也只需要时间和内容两项.
import 'package:hive/hive.dart';

part 'message.g.dart';

@HiveType(typeId: 9)
class Message {
  @HiveField(0)
  final DateTime timestamp;

  @HiveField(1)
  final String content;

  Message({required this.timestamp, required this.content});


  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      timestamp: DateTime.parse(json['timestamp']),
      content: json['content'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "timestamp": timestamp.toLocal().toString().split('.').first,
      "content": content,
    };
  }
}
