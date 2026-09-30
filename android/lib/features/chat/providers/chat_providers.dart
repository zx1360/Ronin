import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/core/services/io/io_service.dart';
import 'package:torrid/core/services/storage/hive_service.dart';
import 'package:torrid/features/chat/models/chat_models.dart';
import 'package:torrid/features/chat/models/chat_options.dart';
import 'package:torrid/features/chat/services/chat_api_service.dart';

part 'chat_providers.g.dart';

/// 对话设置（本地持久化）。
@Riverpod(keepAlive: true)
class ChatOptionsController extends _$ChatOptionsController {
  @override
  ChatOptions build() => loadChatOptions();

  Future<void> update(ChatOptions options) async {
    state = options;
    await saveChatOptions(options);
  }
}

/// 会话列表与当前会话状态。
class ChatState {
  final List<ChatConversation> conversations;

  /// 当前会话 ID；为空表示还没有任何会话。
  final String? activeId;

  /// 正在等待/接收模型回复。
  final bool streaming;

  /// 本轮失败提示（展示在输入框上方，可重试）。
  final String? error;

  /// 一次性提示（如模型被抢占、切换），展示后由页面清除。
  final String? notice;

  const ChatState({
    this.conversations = const [],
    this.activeId,
    this.streaming = false,
    this.error,
    this.notice,
  });

  ChatConversation? get active {
    for (final item in conversations) {
      if (item.id == activeId) return item;
    }
    return conversations.isEmpty ? null : conversations.first;
  }

  ChatState copyWith({
    List<ChatConversation>? conversations,
    String? activeId,
    bool? streaming,
    String? error,
    String? notice,
    bool clearError = false,
    bool clearNotice = false,
  }) {
    return ChatState(
      conversations: conversations ?? this.conversations,
      activeId: activeId ?? this.activeId,
      streaming: streaming ?? this.streaming,
      error: clearError ? null : (error ?? this.error),
      notice: clearNotice ? null : (notice ?? this.notice),
    );
  }
}

/// 聊天控制器：本地会话读写 + 流式请求编排。
///
/// 流式增量只更新内存状态，一轮结束（或失败）时才落库——每个 token 都写一次
/// Hive 既慢又无意义。
@Riverpod(keepAlive: true)
class ChatController extends _$ChatController {
  CancelToken? _cancelToken;

  @override
  ChatState build() {
    ref.onDispose(() => _cancelToken?.cancel());
    final conversations = _sorted(_box.values.toList());
    return ChatState(
      conversations: conversations,
      activeId: conversations.isEmpty ? null : conversations.first.id,
    );
  }

  Box<ChatConversation> get _box =>
      Hive.box<ChatConversation>(HiveService.chatBoxName);

  /// 新建会话并切换过去（顺手清掉此前没说过话的空会话，避免列表越积越多）。
  Future<void> newConversation() async {
    await _persistActive();
    final empties = [
      for (final item in state.conversations)
        if (item.isEmpty) item.id,
    ];
    for (final id in empties) {
      await _box.delete(id);
    }

    final conversation = ChatConversation.empty();
    await _box.put(conversation.id, conversation);
    state = state.copyWith(
      conversations: _sorted([
        for (final item in state.conversations)
          if (!empties.contains(item.id)) item,
        conversation,
      ]),
      activeId: conversation.id,
      clearError: true,
    );
  }

  /// 切换会话。
  Future<void> select(String id) async {
    if (id == state.activeId) return;
    await _persistActive();
    state = state.copyWith(activeId: id, clearError: true);
  }

  /// 删除会话（连同其本地图片）。
  Future<void> deleteConversation(String id) async {
    final target = _conversationById(id);
    await _box.delete(id);
    await _deleteAttachmentFiles(target);

    final remaining = _sorted(
      [...state.conversations]..removeWhere((item) => item.id == id),
    );
    state = state.copyWith(
      conversations: remaining,
      activeId: state.activeId == id && remaining.isNotEmpty
          ? remaining.first.id
          : state.activeId,
      clearError: true,
    );
  }

  /// 清空全部会话（连同本地图片）。
  Future<void> clearAll() async {
    for (final conversation in state.conversations) {
      await _deleteAttachmentFiles(conversation);
    }
    await _box.clear();
    state = const ChatState();
  }

  /// 发送一轮消息（[attachments] 为本轮附带图片）。
  Future<void> send(
    String text, {
    List<ChatAttachment> attachments = const [],
  }) async {
    if (state.streaming) return;
    final prompt = text.trim();
    if (prompt.isEmpty && attachments.isEmpty) return;

    if (state.active == null) await newConversation();
    final conversation = state.active;
    if (conversation == null) return;

    final userMessage = ChatMessage.user(
      content: prompt,
      attachments: attachments,
    );
    final assistantMessage = ChatMessage.assistant();
    final title = conversation.title == '新对话' && prompt.isNotEmpty
        ? _titleOf(prompt)
        : conversation.title;

    final updated = conversation.copyWith(
      title: title,
      messages: [...conversation.messages, userMessage, assistantMessage],
      updatedAt: DateTime.now(),
    );
    await _replaceActive(updated, streaming: true);
    await _runTurn(conversation.id, assistantMessage.id);
  }

  /// 重试：剔除结尾失败的回复后重新请求。
  Future<void> retry() async {
    final conversation = state.active;
    if (conversation == null || state.streaming) return;

    final history = [...conversation.messages];
    while (history.isNotEmpty && !history.last.isUser) {
      history.removeLast();
    }
    if (history.isEmpty) return;

    final assistantMessage = ChatMessage.assistant();
    final updated = conversation.copyWith(
      messages: [...history, assistantMessage],
      updatedAt: DateTime.now(),
    );
    await _replaceActive(updated, streaming: true);
    await _runTurn(conversation.id, assistantMessage.id);
  }

  /// 中断当前回复。
  void stop() {
    _cancelToken?.cancel();
    _cancelToken = null;
  }

  /// 清除一次性提示（页面展示后调用）。
  void clearNotice() => state = state.copyWith(clearNotice: true);

  // ---------- 内部 ----------

  Future<void> _runTurn(String conversationId, String assistantMessageId) async {
    final options = ref.read(chatOptionsControllerProvider);
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;

    try {
      final messages = await _buildRequestMessages(
        _conversationById(conversationId)?.messages ?? const [],
      );
      final stream = ref.read(chatApiProvider).chat(
            messages: messages,
            options: options,
            cancelToken: cancelToken,
          );

      await for (final event in stream) {
        switch (event.type) {
          case 'thinking':
            _patchAssistant(conversationId, assistantMessageId,
                thinking: event.content);
          case 'delta':
            _patchAssistant(conversationId, assistantMessageId,
                content: event.content);
          case 'notice':
            // 服务端告知"抢占了谁"，属于提示而非错误
            state = state.copyWith(notice: event.content);
          case 'aborted':
            // 被另一个模型抢占：标为可重试的中断，不计入上下文
            _patchAssistant(
              conversationId,
              assistantMessageId,
              interrupted: true,
            );
            state = state.copyWith(notice: event.error);
            return;
          case 'error':
            throw AiStreamException(event.error ?? '模型返回错误');
          default:
            break;
        }
      }
      _finishAssistant(conversationId, assistantMessageId);
    } catch (e) {
      final cancelled = e is DioException && e.type == DioExceptionType.cancel;
      _patchAssistant(
        conversationId,
        assistantMessageId,
        error: cancelled ? null : e.toString(),
        interrupted: cancelled,
      );
      state = state.copyWith(
        error: cancelled ? null : e.toString(),
        clearError: cancelled,
      );
    } finally {
      _cancelToken = null;
      state = state.copyWith(streaming: false);
      await _persistActive();
    }
  }

  /// 组装请求消息：只带可用消息，且仅最近两条带图消息重复发送图片。
  ///
  /// 更早的图片对上下文已无价值，却会持续占用上下文窗口与上行带宽。
  Future<List<Map<String, dynamic>>> _buildRequestMessages(
    List<ChatMessage> messages,
  ) async {
    final usable = messages.where((message) => message.usable).toList();
    final keepFrom = _imageKeepIndex(usable);

    final payloads = <Map<String, dynamic>>[];
    for (var i = 0; i < usable.length; i++) {
      final message = usable[i];
      payloads.add({
        'role': message.role,
        'content': message.content,
        if (i >= keepFrom) ...await _attachmentPayload(message.attachments),
      });
    }
    return payloads;
  }

  int _imageKeepIndex(List<ChatMessage> messages) {
    var kept = 0;
    for (var i = messages.length - 1; i >= 0; i--) {
      if (messages[i].attachments.isEmpty) continue;
      kept++;
      if (kept == 2) return i;
    }
    return 0;
  }

  Future<Map<String, List<String>>> _attachmentPayload(
    List<ChatAttachment> items,
  ) async {
    final mediaIds = <String>[];
    final images = <String>[];
    for (final item in items) {
      if (item.isMedia) {
        mediaIds.add(item.mediaId!);
      } else if (item.isLocal) {
        final base64 = await readLocalImage(item.imagePath!);
        if (base64 != null) images.add(base64);
      }
    }
    return {
      if (mediaIds.isNotEmpty) 'media_ids': mediaIds,
      if (images.isNotEmpty) 'images': images,
    };
  }

  Future<void> _deleteAttachmentFiles(ChatConversation? conversation) async {
    if (conversation == null) return;
    for (final message in conversation.messages) {
      for (final attachment in message.attachments) {
        if (!attachment.isLocal) continue;
        try {
          final file = await IoService.getImageFile(attachment.imagePath!);
          if (file != null) await file.delete();
        } catch (_) {
          // 文件已不存在等异常无需打断删除流程
        }
      }
    }
  }

  /// 更新指定会话里某条助手消息（增量拼接思考链与回答）。
  void _patchAssistant(
    String conversationId,
    String messageId, {
    String? content,
    String? thinking,
    String? error,
    bool? interrupted,
  }) {
    final conversation = _conversationById(conversationId);
    if (conversation == null) return;

    final messages = [
      for (final message in conversation.messages)
        if (message.id == messageId && !message.isUser)
          message.copyWith(
            content: '${message.content}${content ?? ''}',
            thinking: '${message.thinking}${thinking ?? ''}',
            error: error,
            interrupted: interrupted,
            clearError: error == null,
          )
        else
          message,
    ];
    state = state.copyWith(
      conversations: _replaceConversation(
        conversation.copyWith(messages: messages, updatedAt: DateTime.now()),
      ),
    );
  }

  /// 一轮结束：模型什么都没返回时标记为失败。
  void _finishAssistant(String conversationId, String messageId) {
    final conversation = _conversationById(conversationId);
    if (conversation == null) return;
    final messages = [
      for (final message in conversation.messages)
        if (message.id == messageId &&
            !message.isUser &&
            message.content.trim().isEmpty)
          message.copyWith(error: '模型没有返回内容')
        else
          message,
    ];
    state = state.copyWith(
      conversations: _replaceConversation(
        conversation.copyWith(messages: messages, updatedAt: DateTime.now()),
      ),
    );
  }

  ChatConversation? _conversationById(String id) {
    for (final conversation in state.conversations) {
      if (conversation.id == id) return conversation;
    }
    return null;
  }

  List<ChatConversation> _replaceConversation(ChatConversation conversation) {
    return _sorted([
      for (final item in state.conversations)
        item.id == conversation.id ? conversation : item,
    ]);
  }

  Future<void> _replaceActive(
    ChatConversation conversation, {
    required bool streaming,
  }) async {
    state = state.copyWith(
      conversations: _replaceConversation(conversation),
      activeId: conversation.id,
      streaming: streaming,
      clearError: true,
    );
    await _box.put(conversation.id, conversation);
  }

  /// 把当前会话落库（一轮结束后调用一次）。
  Future<void> _persistActive() async {
    final conversation = state.active;
    if (conversation == null || conversation.isEmpty) return;
    await _box.put(conversation.id, conversation);
  }

  List<ChatConversation> _sorted(List<ChatConversation> items) {
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }

  String _titleOf(String prompt) {
    final single = prompt.replaceAll(RegExp(r'\s+'), ' ').trim();
    return single.length <= 18 ? single : '${single.substring(0, 18)}…';
  }
}

/// 读取本地图片为 base64（供内联发送）。
Future<String?> readLocalImage(String relativePath) async {
  try {
    final file = await IoService.getImageFile(relativePath);
    if (file == null) return null;
    return base64Encode(await file.readAsBytes());
  } catch (_) {
    return null;
  }
}

/// 服务端在流式事件里返回的错误（对话 / 回顾共用）。
class AiStreamException implements Exception {
  final String message;
  const AiStreamException(this.message);

  @override
  String toString() => message;
}
