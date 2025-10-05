import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/essay/pages/essay_detail_page.dart';
import 'package:torrid/features/essay/pages/essay_overview_page.dart';
import 'package:torrid/features/essay/pages/essay_write_page.dart';
import 'package:torrid/features/essay/providers/essay_provider.dart';
import 'package:torrid/features/essay/widgets/browse_setting.dart';
import 'package:torrid/features/essay/widgets/essay_card.dart';

class EssayBrowsePage extends ConsumerWidget {
  const EssayBrowsePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final essaysAsync = ref.watch(filteredEssaysProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('随笔浏览'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showBrowseSettings(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const EssayOverviewPage()),
            ),
          ),
        ],
      ),
      body: essaysAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('加载失败: $error')),
        data: (essays) {
          if (essays.isEmpty) {
            return const Center(
              child: Text('还没有随笔，点击右下角按钮创建第一篇吧！'),
            );
          }
          
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: essays.length,
            itemBuilder: (context, index) {
              final essay = essays[index];
              return EssayCard(
                essay: essay,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EssayDetailPage(essay: essay),
                  ),
                ),
              );
            },
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