import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:torrid/features/essay/models/year_summary.dart';
import 'package:torrid/features/essay/pages/detail_page.dart';
import 'package:torrid/features/essay/providers/essay_notifier_provider.dart';
import 'package:torrid/features/essay/providers/status_provider.dart';
import 'package:torrid/features/essay/widgets/browse/essay_card.dart';
import 'package:torrid/features/essay/widgets/browse/year_summary_card.dart';

class EssayBrowsePart extends ConsumerStatefulWidget {
  final YearSummary yearSummary;
  const EssayBrowsePart({super.key, required this.yearSummary});

  @override
  ConsumerState<EssayBrowsePart> createState() => _EssayBrowsePartState();
}

class _EssayBrowsePartState extends ConsumerState<EssayBrowsePart>
    with AutomaticKeepAliveClientMixin<EssayBrowsePart> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    final essays = ref.watch(yearEssaysProvider(year: widget.yearSummary.year));
    // TODO: 此处需要.watch()防止contentServerProvider销毁而在detail_page获取不到当前随笔.
    final essay = ref.watch(contentServerProvider);

    super.build(context);
    return SingleChildScrollView(
      child: Column(
        children: [
          // 年度总结部分
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: YearSummaryCard(summary: widget.yearSummary),
          ),
          // 随笔内容浏览
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: essays.length,
            itemBuilder: (context, index) {
              final essay = essays[index];
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
                      MaterialPageRoute(
                        builder: (context) => EssayDetailPage(),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          // 给右下角floating_btn留空.
          SizedBox(height: 80),
        ],
      ),
    );
  }
}
