import 'package:flutter/material.dart';
import 'package:torrid/core/widgets/markdown_widget/markdown_widget.dart';

class ProfileAbout extends StatelessWidget {
  const ProfileAbout({super.key});

  @override
  Widget build(BuildContext context) {
    return NetworkMdBuilder(url: "https://raw.githubusercontent.com/zx1360/Torrid/refs/heads/main/README.md",);
  }
}