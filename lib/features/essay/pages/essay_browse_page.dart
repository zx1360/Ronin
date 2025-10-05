import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/essay/pages/essay_browse_part.dart';

import 'package:torrid/features/essay/pages/essay_write_page.dart';
import 'package:torrid/features/essay/providers/essay_provider.dart';
import 'package:torrid/features/essay/widgets/browse_setting.dart';

class EssayBrowsePage extends ConsumerWidget {
  const EssayBrowsePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: 新增随笔后, 会不会不刷新? (调用加载一下好了.
    final yearSummaries = ref.read(yearSummariesProvider);
    final PageController _controller = PageController();

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
            controller: _controller,
            children: 
            years.map((year)=>EssayBrowsePart(yearSummary: year)).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const EssayWritePage()),
        ),
        child: const Icon(Icons.edit),
      ),
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
