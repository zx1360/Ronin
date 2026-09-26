/// 聊天页本地数据模型（仅存安卓本地 Hive）。
///
/// 一个会话把消息整条存下来：会话数量少、单会话消息量可控，省掉额外的索引表。
library;

import 'package:hive/hive.dart';
import 'package:torrid/core/utils/util.dart';

part 'chat_models.g.dart';

/// 一条对话（会话）。
@HiveType(typeId: 40)
class ChatConversation {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final DateTime createdAt;

  @HiveField(3)
  final DateTime updatedAt;

  @HiveField(4)
  final List<ChatMessage> messages;

  ChatConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
  });

  factory ChatConversation.empty() {
    final now = DateTime.now();
    return ChatConversation(
      id: generateId(),
      title: '新对话',
      createdAt: now,
      updatedAt: now,
      messages: [],
    );
  }

  ChatConversation copyWith({
    String? title,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
  }) {
    return ChatConversation(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
    );
  }

  /// 会话内是否只有一份系统提示以外的空内容（用于剔除"开了没说话"的空会话）。
  bool get isEmpty =>
      messages.every((m) => m.role == 'system' || m.content.trim().isEmpty);
}

/// 消息角色。
class ChatRole {
  static const String user = 'user';
  static const String assistant = 'assistant';
}

/// 一条消息。[thinking] 为模型思考链，[error] 非空表示本轮失败。
@HiveType(typeId: 41)
class ChatMessage {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String role;

  @HiveField(2)
  final String content;

  @HiveField(3)
  final String thinking;

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  final List<ChatAttachment> attachments;

  @HiveField(6)
  final String? error;

  /// 被另一个模型抢占而中断（不是错误，可直接重试）。
  @HiveField(7)
  final bool interrupted;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.thinking,
    required this.createdAt,
    required this.attachments,
    this.error,
    this.interrupted = false,
  });

  ChatMessage.user({required this.content, required this.attachments})
      : id = generateId(),
        role = ChatRole.user,
        thinking = '',
        createdAt = DateTime.now(),
        error = null,
        interrupted = false;

  ChatMessage.assistant({this.content = '', this.thinking = ''})
      : id = generateId(),
        role = ChatRole.assistant,
        createdAt = DateTime.now(),
        attachments = const [],
        error = null,
        interrupted = false;

  ChatMessage copyWith({
    String? content,
    String? thinking,
    List<ChatAttachment>? attachments,
    String? error,
    bool? interrupted,
    bool clearError = false,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      thinking: thinking ?? this.thinking,
      createdAt: createdAt,
      attachments: attachments ?? this.attachments,
      error: clearError ? null : (error ?? this.error),
      interrupted: interrupted ?? this.interrupted,
    );
  }

  bool get isUser => role == ChatRole.user;

  /// 是否可用于后续上下文（失败、被中断或空回复都不参与）。
  bool get usable =>
      error == null && !interrupted && content.trim().isNotEmpty;
}

/// 消息携带的图片：库内媒体（mediaId）或本地图片（imagePath，IoService 相对路径）。
@HiveType(typeId: 42)
class ChatAttachment {
  @HiveField(0)
  final String? mediaId;

  @HiveField(1)
  final String? imagePath;

  @HiveField(2)
  final String? fileName;

  ChatAttachment({this.mediaId, this.imagePath, this.fileName});

  factory ChatAttachment.media(String mediaId, {String? fileName}) =>
      ChatAttachment(mediaId: mediaId, fileName: fileName);

  factory ChatAttachment.local(String imagePath, {String? fileName}) =>
      ChatAttachment(imagePath: imagePath, fileName: fileName);

  bool get isMedia => mediaId != null && mediaId!.isNotEmpty;
  bool get isLocal => imagePath != null && imagePath!.isNotEmpty;
  bool get isValid => isMedia || isLocal;
}

/// "问问AI"跳转参数：带上一张库内图片并直接进入输入态。
class ChatLaunchArgs {
  final List<ChatAttachment> attachments;

  const ChatLaunchArgs({this.attachments = const []});
}
