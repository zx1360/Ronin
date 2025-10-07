import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/essay/pages/essay_browse_part.dart';

import 'package:torrid/features/essay/providers/essay_provider.dart';
import 'package:torrid/features/essay/widgets/browse/floating_dial_btn.dart';
import 'package:torrid/features/essay/widgets/modify/browse_setting.dart';

class EssayBrowsePage extends ConsumerWidget {
  EssayBrowsePage({super.key});

  final PageController controller = PageController();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: ref.read()相比.watch()不会在.when()切换状态, 似乎不适合FutureProvider.
    final yearSummaries = ref.watch(yearSummariesProvider);

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
      body: yearSummaries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('加载失败: $error')),
        data: (years) {
          return PageView(
            controller: controller,
            children: 
            years.map((year)=>EssayBrowsePart(yearSummary: year)).toList(),
          );
        },
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
