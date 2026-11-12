import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/essay/providers/essay_data_provider.dart';

class MessageInputWidget extends ConsumerStatefulWidget {
  final String essayId;
  const MessageInputWidget({super.key, required this.essayId});

  @override
  ConsumerState<MessageInputWidget> createState() => _MessageInputWidgetState();
}

class _MessageInputWidgetState extends ConsumerState<MessageInputWidget> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _saving = false;

  @override
  void dispose() {
    _messageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _addMessage() async {
    final content = _messageController.text.trim();
    if (_saving || content.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(essayStoreProvider)
          .appendMessage(widget.essayId, content);
      if (!mounted) return;
      _messageController.clear();
      _focusNode.unfocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存留言失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _messageController,
          focusNode: _focusNode,
          readOnly: _saving,
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
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            onPressed: _saving ? null : _addMessage,
            icon: Icon(Icons.send, color: Theme.of(context).primaryColor),
          ),
        ),
      ],
    );
  }
}
