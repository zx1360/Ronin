import 'package:flutter/material.dart';
import 'package:torrid/app/theme_book.dart';
import 'package:torrid/features/essay/pages/browse_body.dart';
import 'package:torrid/features/essay/pages/write_page.dart';

import 'package:torrid/features/essay/widgets/browse/setting_widget.dart';

class EssayBrowsePage extends StatelessWidget {
  const EssayBrowsePage({super.key});

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
      // 获取到yearSummaries数据之后, 构建PageView, 左右切换不同年份的随笔.
      body: BrowseBody(),
      floatingActionButton: FloatingActionButton(
        elevation: 6,
        highlightElevation: 10,
        backgroundColor: AppTheme.primary,
        foregroundColor: AppTheme.onPrimary,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const EssayWritePage()),
        ),
        child: const Icon(
          Icons.edit,
          size: 24,
        ),
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
