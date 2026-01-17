import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/core/models/message.dart';
import 'package:torrid/features/essay/providers/essay_notifier_provider.dart';
import 'package:torrid/features/essay/providers/setting_provider.dart';

/// 留言输入组件
/// 用于在随笔详情页添加留言
class MessageInputWidget extends ConsumerStatefulWidget {
  const MessageInputWidget({super.key});

  @override
  ConsumerState<MessageInputWidget> createState() => _MessageInputWidgetState();
}

class _MessageInputWidgetState extends ConsumerState<MessageInputWidget> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _messageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// 添加留言
  void _addMessage() {
    final content = _messageController.text.trim();
    _messageController.clear();
    _focusNode.unfocus();
    if (content.isEmpty) return;

    final essayId = ref.read(contentServerProvider)?.id;
    if (essayId == null) return;

    ref
        .read(essayServiceProvider.notifier)
        .appendMessage(
          essayId,
          Message(timestamp: DateTime.now(), content: content),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _messageController,
          focusNode: _focusNode,
          minLines: 2,
          maxLines: null,
          decoration: InputDecoration(
            hintText: '添加留言...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24.0),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24.0),
              borderSide: BorderSide(color: Theme.of(context).primaryColor),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
          ),
          onTapOutside: (event) => _focusNode.unfocus(),
        ),
        const SizedBox(width: 8.0),
        // TODO: routine的表情添加可以置于此?
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            onPressed: _addMessage,
            icon: Icon(Icons.send, color: Theme.of(context).primaryColor),
          ),
        ),
      ],
    );
  }
}
