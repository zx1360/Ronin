import 'package:flutter/material.dart';
import 'package:torrid/features/essay/models/year_summary.dart';
import 'package:torrid/features/essay/widgets/overview/writing_trend_chart.dart';

class YearSummaryCard extends StatelessWidget {
  final YearSummary summary;
  final VoidCallback? onTap;

  const YearSummaryCard({super.key, required this.summary, this.onTap});

  @override
  Widget build(BuildContext context) {
    final allYears = summary.year == '-1';
    final theme = Theme.of(context);
    final periods = summary.monthSummaries;
    final best = periods.isEmpty
        ? null
        : periods.reduce((a, b) => a.essayCount > b.essayCount ? a : b);
    final stats = [
      ('总篇数', '${summary.essayCount}'),
      ('总字数', '${summary.wordCount}'),
      (
        '单篇平均',
        '${summary.essayCount == 0 ? 0 : (summary.wordCount / summary.essayCount).round()}',
      ),
      if (allYears) ...[
        ('跨越年份', '${periods.length}'),
        if (best != null) ('最高产年份', best.month),
        if (best != null) ('该年篇数', '${best.essayCount}'),
      ],
    ];
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      allYears ? '全部随笔' : '${summary.year} 年',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  if (onTap != null) const Icon(Icons.chevron_right, size: 20),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  for (final (label, value) in stats)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          value,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Text(label, style: theme.textTheme.bodySmall),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                allYears ? '年度写作分布（篇数）' : '月度写作趋势（字数）',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              WritingTrendChart(
                periods: periods,
                yearly: allYears,
                byCount: allYears,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
