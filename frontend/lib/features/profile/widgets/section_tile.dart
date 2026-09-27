import 'package:flutter/material.dart';



// 构建分组(标题和各个tile组件)
class SectionTile extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const SectionTile({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
          child: Text(
            title,
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ),
        ...children,
      ],
    );
  }
}

