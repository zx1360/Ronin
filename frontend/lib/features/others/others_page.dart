import 'package:flutter/material.dart';
import 'package:torrid/features/others/entry_button.dart';

import 'package:torrid/features/others/pages_data.dart';

class OthersPage extends StatelessWidget {
  const OthersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('其他功能')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
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
