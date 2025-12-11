import 'package:flutter/material.dart';

class DialogOption {
  final String text;
  final Function onPressed;
  final Color? textColor;

  DialogOption({
    required this.text,
    required this.onPressed,
    this.textColor,
  });
}
