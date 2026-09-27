import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/app/theme/theme_book.dart';
import 'package:torrid/core/api/generated/api_contract.dart' show ApiPath;
import 'package:torrid/core/services/io/io_service.dart';
import 'package:torrid/core/widgets/markdown_widget/md_viewer.dart';
import 'package:torrid/features/chat/models/chat_models.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

/// 单条消息气泡：图片附件 + 思考链（可折叠）+ 正文 + 失败重试。
class ChatMessageBubble extends ConsumerStatefulWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    this.streaming = false,
    this.onRetry,
  });

  final ChatMessage message;

  /// 该消息仍在接收中（未落库的当前轮）。
  final bool streaming;
  final VoidCallback? onRetry;

  @override
  ConsumerState<ChatMessageBubble> createState() => _ChatMessageBubbleState();
}

class _ChatMessageBubbleState extends ConsumerState<ChatMessageBubble> {
  /// 思考链默认展开；正文一开始输出就收起，避免长思考挤占视线。
  bool? _thinkingExpanded;

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final isUser = message.isUser;
    final thinking = message.thinking.trim();
    final hasContent = message.content.trim().isNotEmpty;
    final expanded = _thinkingExpanded ?? (!hasContent && widget.streaming);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) const _Avatar(),
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (message.attachments.isNotEmpty)
                  _AttachmentStrip(attachments: message.attachments),
                if (thinking.isNotEmpty)
                  _ThinkingPanel(
                    text: thinking,
                    expanded: expanded,
                    streaming: widget.streaming,
                    onToggle: () =>
                        setState(() => _thinkingExpanded = !expanded),
                  ),
                if (hasContent || (!isUser && !widget.streaming))
                  _buildBody(context),
                if (message.interrupted) _buildInterrupted(context),
                if (message.error != null) _buildError(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 长按复制。气泡内文本刻意不可选中：文本选择器会抢走上下拖动的手势，
  /// 导致"拖动正文时整页滑不动"（自用场景下复制用长按更顺手）。
  Future<void> _copy() async {
    final text = widget.message.content.trim();
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1)),
    );
  }

  Widget _buildBody(BuildContext context) {
    final message = widget.message;
    final isUser = message.isUser;
    return GestureDetector(
      onLongPress: _copy,
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? AppTheme.primary : AppTheme.surfaceContainer,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isUser ? 14 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 14),
          ),
          border: isUser
              ? null
              : Border.all(color: AppTheme.outline.withAlpha(120)),
        ),
        child: isUser
            ? Text(
                message.content,
                style: const TextStyle(
                  color: AppTheme.onPrimary,
                  fontSize: 15,
                  height: 1.4,
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MdViewer(
                    data: message.content.isEmpty ? ' ' : message.content,
                    selectable: false,
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                  ),
                  if (widget.streaming && message.content.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: _TypingDots(),
                    ),
                ],
              ),
      ),
    );
  }

  /// 被另一个模型抢占：中性提示 + 继续（不是错误）。
  Widget _buildInterrupted(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.pause_circle_outline,
              size: 14, color: AppTheme.onSurfaceVariant),
          const SizedBox(width: 4),
          const Text(
            '已中断',
            style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
          ),
          if (widget.onRetry != null)
            TextButton(
              onPressed: widget.onRetry,
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('继续', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 14, color: AppTheme.errorVivid),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              widget.message.error!,
              style: const TextStyle(fontSize: 12, color: AppTheme.errorVivid),
            ),
          ),
          if (widget.onRetry != null)
            TextButton(
              onPressed: widget.onRetry,
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

/// 助手头像。
class _Avatar extends StatelessWidget {
  const _Avatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      margin: const EdgeInsets.only(right: 8, top: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.auto_awesome, size: 15, color: AppTheme.primary),
    );
  }
}

/// 思考链面板。
class _ThinkingPanel extends StatelessWidget {
  const _ThinkingPanel({
    required this.text,
    required this.expanded,
    required this.streaming,
    required this.onToggle,
  });

  final String text;
  final bool expanded;
  final bool streaming;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWarm,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.outline.withAlpha(120)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.psychology_outlined,
                      size: 14, color: AppTheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    streaming && text.isEmpty ? '思考中…' : '思考过程',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    size: 15,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 消息附带的图片。
class _AttachmentStrip extends ConsumerWidget {
  const _AttachmentStrip({required this.attachments});

  final List<ChatAttachment> attachments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(apiClientManagerProvider);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final item in attachments)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 96,
                height: 96,
                child: item.isMedia
                    ? CachedNetworkImage(
                        imageUrl:
                            '${api.baseUrl}${ApiPath.galleryIdTypePath(item.mediaId!, 'thumb')}',
                        httpHeaders: api.headers,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const _BrokenImage(),
                      )
                    : _LocalImage(relativePath: item.imagePath ?? ''),
              ),
            ),
        ],
      ),
    );
  }
}

/// 本地图片（IoService 相对路径）。
class _LocalImage extends StatelessWidget {
  const _LocalImage({required this.relativePath});

  final String relativePath;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: IoService.getImageFile(relativePath),
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file == null) return const _BrokenImage();
        return Image.file(file, fit: BoxFit.cover);
      },
    );
  }
}

class _BrokenImage extends StatelessWidget {
  const _BrokenImage();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surfaceContainerHighest,
      child: const Icon(Icons.broken_image_outlined,
          size: 20, color: AppTheme.onSurfaceVariant),
    );
  }
}

/// 输出中的动态省略号。
class _TypingDots extends StatelessWidget {
  const _TypingDots();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 12,
      height: 6,
      child: CircularProgressIndicator(strokeWidth: 1.6),
    );
  }
}
