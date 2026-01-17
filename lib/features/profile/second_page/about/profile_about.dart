import 'package:flutter/material.dart';
import 'package:torrid/core/widgets/markdown_widget/assets_md_builder.dart';

class ProfileAbout extends StatelessWidget {
  const ProfileAbout({super.key});

  @override
  Widget build(BuildContext context) {
    return AssetsMdBuilder(mdPath: 'assets/files/README.md');
  }
}