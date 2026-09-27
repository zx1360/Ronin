import 'package:flutter/material.dart';

// 显示提示信息
void displaySnackBar(BuildContext context, String message) {
  if (context.mounted) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }
}