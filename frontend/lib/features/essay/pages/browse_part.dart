import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:torrid/features/essay/models/year_summary.dart';
import 'package:torrid/features/essay/pages/detail_page.dart';
import 'package:torrid/features/essay/pages/year_overview_page.dart';
import 'package:torrid/features/essay/providers/setting_provider.dart';
import 'package:torrid/features/essay/providers/status_provider.dart';
import 'package:torrid/features/essay/widgets/browse/essay_card.dart';
import 'package:torrid/features/essay/widgets/browse/year_summary_card.dart';

class BrowsePart extends ConsumerStatefulWidget {
  final YearSummary yearSummary;
  const BrowsePart({super.key, required this.yearSummary});

  @override
  ConsumerState<BrowsePart> createState() => BrowsePartState();
}

class BrowsePartState extends ConsumerState<BrowsePart> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final essaysAsync = ref.watch(
      yearEssaysProvider(year: widget.yearSummary.year),
    );
    ref.watch(contentServerProvider); //防止contentServerProvider被销毁.

    return essaysAsync.when(
      error: (error, stack) => Center(child: Text('加载失败：$error')),
      loading: () => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: YearSummaryCard(
              summary: widget.yearSummary,
              onTap: () => _navigateToOverview(context),
            ),
          ),
          const Center(child: CircularProgressIndicator()),
        ],
      ),
      data: (essays) => ListView.builder(
        controller: _scrollController,
        itemCount: essays.length + 2,
        itemBuilder: (context, index) {
          // 年度概览
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: YearSummaryCard(
                summary: widget.yearSummary,
                onTap: () => _navigateToOverview(context),
              ),
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

  /// 跳转到年度概览页面
  void _navigateToOverview(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => YearOverviewPage(summary: widget.yearSummary),
      ),
    );
  }
}
