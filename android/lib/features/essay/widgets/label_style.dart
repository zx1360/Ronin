import 'package:flutter/material.dart';

Color essayLabelColor(String path, Brightness brightness) {
  const palette = [
    Color(0xFF497C78),
    Color(0xFF6675A5),
    Color(0xFFA47742),
    Color(0xFF94708C),
    Color(0xFF587D9C),
    Color(0xFF77844F),
  ];
  final root = path.split(' / ').first;
  final seed = root.codeUnits.fold(
    0,
    (value, unit) => (value * 31 + unit) % 997,
  );
  final color = root == '隐藏'
      ? const Color(0xFF7A7380)
      : palette[seed % palette.length];
  return brightness == Brightness.dark
      ? Color.lerp(color, Colors.white, 0.3)!
      : color;
}

class EssayLabelChip extends StatelessWidget {
  final String path;

  const EssayLabelChip({super.key, required this.path});

  @override
  Widget build(BuildContext context) {
    final color = essayLabelColor(path, Theme.of(context).brightness);
    return Tooltip(
      message: path,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          path.split(' / ').last,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
