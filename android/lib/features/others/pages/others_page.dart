import 'package:flutter/material.dart';
import 'package:torrid/features/others/widgets/entry_button.dart';

import 'package:torrid/features/others/widgets/pages_data.dart';

class OthersPage extends StatelessWidget {
  const OthersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('媒体')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.extent(
          maxCrossAxisExtent: MediaQuery.textScalerOf(context).scale(14) > 20
              ? 500
              : 260,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: MediaQuery.textScalerOf(context).scale(14) > 20
              ? 220
              : 160,
          children: OtherPagesData.pages
              .map((page) => PageEntryButton(pageItem: page))
              .toList(),
        ),
      ),
    );
  }
}
