import 'package:flutter/material.dart';

class ActionInfo {
  final IconData icon;
  final String label;
  final Future<void> Function() action;
  final bool highlighted;

  ActionInfo({
    required this.icon,
    required this.label,
    required this.action,
    this.highlighted = false,
  });
}