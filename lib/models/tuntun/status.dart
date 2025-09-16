import 'package:hive/hive.dart';
import 'package:torrid/models/common/message.dart';

part "status.g.dart";

@HiveType(typeId: 21)
class Status {
  @HiveField(0)
  final String mediaId;

  @HiveField(1)
  final List<String> tags;

  @HiveField(2)
  final List<String> bundleWith;

  @HiveField(3)
  final bool isMarkedDeleted;

  @HiveField(4)
  final List<Message> messages;

  Status({
    required this.mediaId,
    this.tags = const [],
    this.bundleWith = const [],
    this.isMarkedDeleted = false,
    this.messages = const [],
  });

  Status copyWith({
    String? mediaId,
    List<String>? tags,
    List<String>? bundleWith,
    bool? isMarkedDeleted,
    List<Message>? messages,
  }) {
    return Status(
      mediaId: mediaId ?? this.mediaId,
      tags: tags ?? this.tags,
      bundleWith: bundleWith ?? this.bundleWith,
      isMarkedDeleted: isMarkedDeleted ?? this.isMarkedDeleted,
      messages: messages ?? this.messages,
    );
  }

  factory Status.fromJson(dynamic json) {
    return Status(
      mediaId: json['mediaId'],
      tags: json['tags'] as List<String>,
      bundleWith: json['bundleWith'] as List<String>,
      isMarkedDeleted: json['isMarkedDeleted'],
      messages: (json['messages'] as List)
          .map((item) => Message.fromJson(item))
          .toList(),
    );
  }

  dynamic toJson(){
    return {
      "mediaId": mediaId,
      "tags": tags,
      "bundleWith": bundleWith,
      "isMarkedDeleted": isMarkedDeleted,
      "messages": messages.map((item)=>item.toJson()).toList()
    };
  }
}
