import 'package:flutter/material.dart';

/// 文本输入对话框; 返回 null 表示取消
Future<String?> showTextInputDialog(
  BuildContext context, {
  required String title,
  String initial = '',
  String? label,
  String? hint,
  int maxLines = 1,
  int? maxLength,
  bool allowEmpty = true,
  String confirmText = '确定',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextInputDialog(
      title: title,
      initial: initial,
      label: label,
      hint: hint,
      maxLines: maxLines,
      maxLength: maxLength,
      allowEmpty: allowEmpty,
      confirmText: confirmText,
    ),
  );
}

class _TextInputDialog extends StatefulWidget {
  final String title;
  final String initial;
  final String? label;
  final String? hint;
  final int maxLines;
  final int? maxLength;
  final bool allowEmpty;
  final String confirmText;

  const _TextInputDialog({
    required this.title,
    required this.initial,
    required this.maxLines,
    required this.maxLength,
    required this.allowEmpty,
    required this.confirmText,
    this.label,
    this.hint,
  });

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (widget.allowEmpty || value.isNotEmpty) Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: widget.maxLines,
        maxLength: widget.maxLength,
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
