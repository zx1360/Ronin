import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:torrid/app/theme/theme_book.dart';
import 'package:torrid/features/chat/models/chat_models.dart';
import 'package:torrid/features/chat/providers/chat_providers.dart';
import 'package:torrid/features/chat/widgets/chat_composer.dart';
import 'package:torrid/features/chat/widgets/chat_message_bubble.dart';
import 'package:torrid/features/chat/widgets/conversation_drawer.dart';

/// 对话页：与本地 Ollama + Qwen 对话，支持上传图片、思考链与多会话。
///
/// [args] 由"问问AI"入口传入：预置图片附件并直接进入输入态。
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key, this.args});

  final ChatLaunchArgs? args;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// "问问AI"带过来的附件：首次发送后即失效，避免切换会话时反复预置。
  late List<ChatAttachment> _launchAttachments = [
    ...?widget.args?.attachments,
  ];

  /// 是否自动贴住最新内容：用户向上翻阅历史时置为 false，回到底部再置回。
  bool _stickToBottom = true;

  /// 距底部多远仍视为"在底部"（留一点余量，避免像素级误差导致不贴底）。
  static const double _bottomTolerance = 48;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 仅在"贴底"状态下跟随新内容；用户翻阅历史时绝不强拉。
  void _scrollToBottomIfSticking() {
    if (!_stickToBottom) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  void _jumpToBottom() {
    setState(() => _stickToBottom = true);
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  /// 用户拖动/惯性滚动后重新判断是否贴底。
  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    final position = notification.metrics;
    final atBottom = position.maxScrollExtent - position.pixels <= _bottomTolerance;
    if (atBottom != _stickToBottom) {
      setState(() => _stickToBottom = atBottom);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatControllerProvider);
    final controller = ref.read(chatControllerProvider.notifier);
    final conversation = state.active;

    // 流式增量：内容变长时贴底跟随
    ref.listen(chatControllerProvider, (previous, next) {
      if (previous == next) return;
      _scrollToBottomIfSticking();
    });

    // 服务端提示（如模型被抢占）用 SnackBar 呈现一次
    ref.listen(chatControllerProvider.select((value) => value.notice),
        (previous, next) {
      if (next == null || next == previous) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(next), duration: const Duration(seconds: 3)),
      );
      controller.clearNotice();
    });

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        // AppBar有自带leadingWidget打开Drawer.
        title: Text(
          conversation?.title ?? '对话',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 17),
        ),
        actions: [
          IconButton(
            tooltip: '新对话',
            onPressed: () => controller.newConversation(),
            icon: const Icon(Icons.add_comment_outlined),
          ),
          IconButton(
            tooltip: '对话设置',
            onPressed: () => context.pushNamed('chat_settings'),
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      drawer: const ChatConversationDrawer(),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _onScroll,
                    child: _buildMessageList(state),
                  ),
                ),
                if (!_stickToBottom)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: FloatingActionButton.small(
                      heroTag: 'chat_scroll_bottom',
                      tooltip: '回到最新',
                      onPressed: _jumpToBottom,
                      child: const Icon(Icons.arrow_downward_rounded, size: 18),
                    ),
                  ),
              ],
            ),
          ),
          if (state.error != null) _buildErrorBar(state.error!, controller),
          ChatComposer(
            key: ValueKey(conversation?.id ?? 'empty'),
            streaming: state.streaming,
            initialAttachments: _launchAttachments,
            autoFocus: _launchAttachments.isNotEmpty,
            onSend: (text, attachments) {
              if (_launchAttachments.isNotEmpty) {
                setState(() => _launchAttachments = const []);
              }
              // 发送即回到最新
              _stickToBottom = true;
              controller.send(text, attachments: attachments);
            },
            onStop: controller.stop,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(ChatState state) {
    final conversation = state.active;
    final messages = conversation?.messages ?? const <ChatMessage>[];

    if (messages.isEmpty) {
      return const _EmptyHint();
    }

    final lastId = messages.last.id;
    return ListView.builder(
      controller: _scrollController,
      // 始终可滚动：内容不足一屏时也不做回弹，拖动手感稳定
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isLast = index == messages.length - 1;
        return ChatMessageBubble(
          key: ValueKey(message.id),
          message: message,
          streaming: state.streaming && message.id == lastId && !message.isUser,
          onRetry: isLast &&
                  (message.error != null || message.interrupted)
              ? () => ref.read(chatControllerProvider.notifier).retry()
              : null,
        );
      },
    );
  }

  Widget _buildErrorBar(String error, ChatController controller) {
    return Container(
      width: double.infinity,
      color: AppTheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              error,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.onErrorContainer,
              ),
            ),
          ),
          TextButton(
            onPressed: controller.retry,
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('重试', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

/// 空会话引导。
class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome,
              size: 42, color: AppTheme.primary.withAlpha(150)),
          const SizedBox(height: 12),
          const Text(
            '本地 Qwen 对话',
            style: TextStyle(fontSize: 15, color: AppTheme.onSurface),
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              '离线运行，可上传图片一起提问；对话记录只保存在本机。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
