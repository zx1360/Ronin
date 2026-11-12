import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/essay/models/label_tree.dart';
import 'package:torrid/features/essay/models/year_summary.dart';
import 'package:torrid/features/essay/pages/detail_page.dart';
import 'package:torrid/features/essay/pages/year_overview_page.dart';
import 'package:torrid/features/essay/providers/essay_data_provider.dart';
import 'package:torrid/features/essay/providers/status_provider.dart';
import 'package:torrid/features/essay/widgets/browse/essay_card.dart';
import 'package:torrid/features/essay/widgets/browse/year_summary_card.dart';

class BrowseList extends ConsumerStatefulWidget {
  final String year;

  const BrowseList({super.key, required this.year});

  @override
  ConsumerState<BrowseList> createState() => BrowseListState();
}

class BrowseListState extends ConsumerState<BrowseList>
    with AutomaticKeepAliveClientMixin {
  final _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

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
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final allYears = widget.year == '-1';
    final essaysAsync = allYears
        ? ref.watch(filteredEssaysProvider)
        : ref.watch(yearEssaysProvider(year: widget.year));
    final labels = ref.watch(labelStreamProvider).value ?? const [];
    return essaysAsync.when(
      skipLoadingOnReload: true,
      error: (error, stack) => Center(child: Text('加载失败：$error')),
      loading: () => const Center(child: CircularProgressIndicator()),
      data: (essays) {
        final summary = YearSummary.fromEssays(
          widget.year,
          visibleEssays(essays, labels),
        );
        Map<String, int>? indices;
        return ListView.builder(
          key: PageStorageKey('essay-list-${widget.year}'),
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          itemCount: essays.length + 1,
          findChildIndexCallback: (key) {
            final id = (key as ValueKey<String>).value;
            if (id == 'summary') return 0;
            return (indices ??= {
              for (final (index, essay) in essays.indexed) essay.id: index + 1,
            })[id];
          },
          itemBuilder: (context, index) => Padding(
            key: ValueKey(index == 0 ? 'summary' : essays[index - 1].id),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: index == 0
                ? YearSummaryCard(
                    summary: summary,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => YearOverviewPage(summary: summary),
                      ),
                    ),
                  )
                : EssayCard(
                    essay: essays[index - 1],
                    showYear: allYears,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            EssayDetailPage(essayId: essays[index - 1].id),
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }
}
