import 'package:flutter/material.dart';

Future<bool> showDangerConfirmDialog({
  required BuildContext context,
  required String phrase,
  required String title,
}) async {
  final controller = TextEditingController();
  var errorText = '';

  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('该操作存在风险，请输入下方确认短语后继续：'),
                  const SizedBox(height: 12),
                  SelectableText(
                    phrase,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: '确认短语',
                      errorText: errorText.isEmpty ? null : errorText,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (controller.text.trim() != phrase) {
                    setState(() {
                      errorText = '输入内容与确认短语不一致';
                    });
                    return;
                  }
                  Navigator.of(dialogContext).pop(true);
                },
                child: const Text('确认执行'),
              ),
            ],
          );
        },
      );
    },
  );

  controller.dispose();
  return confirmed == true;
}
