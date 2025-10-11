import 'package:flutter/material.dart';
import 'package:torrid/shared/widgets/markdown_widget/assets_md_builder.dart';

class ProfileHelp extends StatelessWidget {
  const ProfileHelp({super.key});

  @override
  Widget build(BuildContext context) {
    return AssetsMdBuilder(mdPath: 'assets/files/help.md');
  }
}