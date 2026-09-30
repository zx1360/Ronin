import 'package:flutter/material.dart';

/// 紧凑图标按钮（带 Tooltip）。
///
/// 标签树面板与标签列表页各写过一份，只差内边距，这里合并为一个可调间距的实现。
class TagIconTap extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;
  final double padding;

  const TagIconTap({
    super.key,
    required this.icon,
    required this.color,
    required this.tooltip,
    this.onTap,
    this.padding = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}
