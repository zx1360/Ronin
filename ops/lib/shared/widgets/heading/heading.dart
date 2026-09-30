import 'package:flutter/material.dart';

// 顶部标题
class Heading extends StatelessWidget {
  final String title;
  const Heading({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: SizedBox(
          height: 48,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(title, style: textTheme.titleLarge),
          ),
        ),
      ),
    );
  }
}
