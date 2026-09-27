import 'package:flutter/material.dart';
import 'package:torrid/features/essay/pages/browse_body.dart';
import 'package:torrid/features/essay/pages/write_page.dart';
import 'package:torrid/features/essay/widgets/browse/expandable_fab.dart';

import 'package:torrid/features/essay/widgets/browse/setting_widget.dart';

class EssayBrowsePage extends StatefulWidget {
  const EssayBrowsePage({super.key});

  @override
  State<EssayBrowsePage> createState() => _EssayBrowsePageState();
}

class _EssayBrowsePageState extends State<EssayBrowsePage> {
  final GlobalKey<BrowseBodyState> _browseBodyKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('随笔'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showBrowseSettings(context),
          ),
        ],
      ),
      body: BrowseBody(key: _browseBodyKey),
      floatingActionButton: ExpandableFab(
        distance: 70,
        actions: [
          FabAction(
            icon: Icons.vertical_align_top,
            label: '回到顶部',
            onPressed: () {
              _browseBodyKey.currentState?.scrollToTop();
            },
          ),
          FabAction(
            icon: Icons.edit,
            label: '写随笔',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EssayWritePage()),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showBrowseSettings(BuildContext context) {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SettingWidget(),
    );
  }
}
