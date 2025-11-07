import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:torrid/features/essay/models/year_summary.dart';
import 'package:torrid/features/essay/pages/detail_page.dart';
import 'package:torrid/features/essay/providers/setting_provider.dart';
import 'package:torrid/features/essay/providers/status_provider.dart';
import 'package:torrid/features/essay/widgets/browse/essay_card.dart';
import 'package:torrid/features/essay/widgets/browse/year_summary_card.dart';

class BrowsePart extends ConsumerWidget {
  final YearSummary yearSummary;
  const BrowsePart({super.key, required this.yearSummary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final essaysAsync = ref.watch(yearEssaysProvider(year: yearSummary.year));
    // TODO: 此处需要.watch()防止contentServerProvider销毁而在detail_page获取不到当前随笔.
    final essay = ref.watch(contentServerProvider);

    return essaysAsync.when(
      error: (error, stack) => Center(child: Text('加载失败：$error')),
      loading: () => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: YearSummaryCard(summary: yearSummary),
          ),
          const Center(child: CircularProgressIndicator()),
        ],
      ),
      data: (essays) => ListView.builder(
        shrinkWrap: true,
        itemCount: essays.length + 2,
        itemBuilder: (context, index) {
          // 年度概览
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: YearSummaryCard(summary: yearSummary),
            );
          }
          // 给右下角floating_btn留空.
          if (index == essays.length + 1) {
            return SizedBox(height: 80);
          }
          final essay = essays[index - 1];
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: EssayCard(
              essay: essay,
              onTap: () {
                ref.read(contentServerProvider.notifier).switchEssay(essay);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => EssayDetailPage()),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
