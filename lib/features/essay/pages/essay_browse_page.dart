import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/essay/pages/essay_browse_part.dart';

import 'package:torrid/features/essay/providers/status_provider.dart';
import 'package:torrid/features/essay/widgets/browse/floating_dial_btn.dart';
import 'package:torrid/features/essay/widgets/modify/browse_setting.dart';

class EssayBrowsePage extends ConsumerWidget {
  EssayBrowsePage({super.key});

  final PageController controller = PageController();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yearSummaries = ref.watch(summariesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('随笔'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showBrowseSettings(context, ref),
          ),
        ],
      ),
      // 获取到yearSummaries数据之后, 构建PageView, 左右切换不同年份的随笔.
      body: PageView(
        controller: controller,
        children: yearSummaries
            .map((year) => EssayBrowsePart(yearSummary: year))
            .toList(),
      ),
      floatingActionButton: FloatingDialBtn(),
    );
  }

  void _showBrowseSettings(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => BrowseSettingsBottomSheet(),
    );
  }
}
