import 'package:flutter/material.dart';
import 'package:torrid/features/others/widgets/entry_button.dart';

import 'package:torrid/features/others/widgets/pages_data.dart';

class OthersPage extends StatelessWidget {
  const OthersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('其他功能'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          // 每行显示2个项目
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          // 子项宽高比
          childAspectRatio: 1.2,
          children: OtherPagesData.pages
              .map((page) => PageEntryButton(pageItem: page))
              .toList(),
        ),
      ),
    );
  }
}
