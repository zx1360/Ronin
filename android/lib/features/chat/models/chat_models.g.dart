// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatMessage _$ChatMessageFromJson(Map<String, dynamic> json) => ChatMessage(
  id: json['id'] as String,
  role: json['role'] as String,
  content: json['content'] as String,
  thinking: json['thinking'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  attachments: (json['attachments'] as List<dynamic>)
      .map((e) => ChatAttachment.fromJson(e as Map<String, dynamic>))
      .toList(),
  error: json['error'] as String?,
  interrupted: json['interrupted'] as bool? ?? false,
);

Map<String, dynamic> _$ChatMessageToJson(ChatMessage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'role': instance.role,
      'content': instance.content,
      'thinking': instance.thinking,
      'createdAt': instance.createdAt.toIso8601String(),
      'attachments': instance.attachments,
      'error': instance.error,
      'interrupted': instance.interrupted,
    };

ChatAttachment _$ChatAttachmentFromJson(Map<String, dynamic> json) =>
    ChatAttachment(
      mediaId: json['mediaId'] as String?,
      imagePath: json['imagePath'] as String?,
      fileName: json['fileName'] as String?,
    );

Map<String, dynamic> _$ChatAttachmentToJson(ChatAttachment instance) =>
    <String, dynamic>{
      'mediaId': instance.mediaId,
      'imagePath': instance.imagePath,
      'fileName': instance.fileName,
    };
