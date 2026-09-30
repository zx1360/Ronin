import 'package:flutter/material.dart';

/// 文本输入对话框; 返回 null 表示取消
Future<String?> showImmichTextDialog(
  BuildContext context, {
  required String title,
  String initial = '',
  String? label,
  String? hint,
  int maxLines = 1,
  String confirmText = '确定',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _ImmichTextDialog(
      title: title,
      initial: initial,
      label: label,
      hint: hint,
      maxLines: maxLines,
      confirmText: confirmText,
    ),
  );
}

/// 确认对话框; 返回是否确认
Future<bool> showImmichConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmText = '确定',
  bool danger = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('取消'),
        ),
        FilledButton(
          style: danger
              ? FilledButton.styleFrom(backgroundColor: Colors.red)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmText),
        ),
      ],
    ),
  );
  return result == true;
}

class _ImmichTextDialog extends StatefulWidget {
  final String title;
  final String initial;
  final String? label;
  final String? hint;
  final int maxLines;
  final String confirmText;

  const _ImmichTextDialog({
    required this.title,
    required this.initial,
    required this.maxLines,
    required this.confirmText,
    this.label,
    this.hint,
  });

  @override
  State<_ImmichTextDialog> createState() => _ImmichTextDialogState();
}

class _ImmichTextDialogState extends State<_ImmichTextDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: widget.maxLines,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmText)),
      ],
    );
  }
}
