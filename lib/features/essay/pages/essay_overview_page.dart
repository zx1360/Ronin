import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/essay/providers/essay_provider.dart';
import 'package:torrid/features/essay/widgets/year_summary_card.dart';

class EssayOverviewPage extends ConsumerWidget {
  const EssayOverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yearSummariesAsync = ref.watch(yearSummariesProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('随笔总览'),
      ),
      body: yearSummariesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('加载失败: $error')),
        data: (yearSummaries) {
          if (yearSummaries.isEmpty) {
            return const Center(
              child: Text('还没有随笔数据'),
            );
          }
          
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: yearSummaries.length,
            itemBuilder: (context, index) {
              final yearSummary = yearSummaries[index];
              return YearSummaryCard(yearSummary: yearSummary);
            },
          );
        },
      ),
    );
  }
}