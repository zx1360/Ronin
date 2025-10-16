import 'package:hive/hive.dart';
import 'package:torrid/shared/models/message.dart';
import 'package:torrid/shared/utils/util.dart';

part 'mission.g.dart';

@HiveType(typeId: 15)
class Mission {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final String? image;

  @HiveField(4)
  final List<Message> messages;

  // 0: inProgress进行中, 1: completed已完成, 2: terminated已中断.
  @HiveField(5)
  final int status;

  @HiveField(6)
  final DateTime startTime;

  @HiveField(7)
  final DateTime? terminateDate;

  @HiveField(8)
  final DateTime? deadline;

  Mission({
    required this.id,
    required this.title,
    required this.description,
    this.image,
    this.messages = const [],
    required this.status,
    required this.startTime,
    this.terminateDate,
    this.deadline,
  });

  factory Mission.fromJson(Map<String, dynamic> json) {
    return Mission(
      id: (json['id']as String).length<17? generateId(): json['id'],
      title: json['title'],
      description: json['description'],
      image: json['image'],
      messages: (json['messages']as List).map((item)=>Message.fromJson(item)).toList(),
      status: json['status'],
      startTime: json['startTime'],
      terminateDate: json['terminateDate'],
      deadline: json['deadline'],
    );
  }

  Map<String, dynamic> toJson(){
    return {
      "id": id,
      "title": title,
      "description": description,
      "image": image,
      "messages": messages.map((item)=>item.toJson()).toList(),
      "status": status,
      "startTime": startTime..toLocal().toString().split('.').first,
      "terminateDate": terminateDate?.toLocal().toString().split('.').first,
      "deadline": deadline?.toLocal().toString().split('.').first,
    };
  }
}
