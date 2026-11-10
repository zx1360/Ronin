import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:torrid/features/essay/models/year_summary.dart';

class WritingTrendChart extends StatelessWidget {
  final List<MonthSummary> periods;
  final bool yearly;
  final bool byCount;

  const WritingTrendChart({
    super.key,
    required this.periods,
    this.yearly = false,
    this.byCount = false,
  });

  @override
  Widget build(BuildContext context) {
    final byPeriod = {for (final period in periods) period.month: period};
    final data = yearly
        ? (periods.toList()..sort((a, b) => a.month.compareTo(b.month)))
        : [
            for (var month = 1; month <= 12; month++)
              byPeriod['$month'] ?? MonthSummary(month: '$month'),
          ];
    if (data.isEmpty) return const Center(child: Text('暂无数据'));
    int value(MonthSummary period) =>
        byCount ? period.essayCount : period.wordCount;
    final maximum = data.fold(1, (n, period) => math.max(n, value(period)));
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final minWidth = MediaQuery.textScalerOf(
          context,
        ).scale(yearly ? 46 : 28);
        final columns = (constraints.maxWidth / minWidth).floor().clamp(1, 12);
        return Wrap(
          runSpacing: 12,
          children: [
            for (final period in data)
              SizedBox(
                width: constraints.maxWidth / columns,
                child: Tooltip(
                  message:
                      '${period.month}${yearly ? '年' : '月'}：${period.essayCount} 篇 · ${period.wordCount} 字',
                  child: Column(
                    children: [
                      SizedBox(
                        height: 80,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: 14,
                            height: value(period) / maximum * 80,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${period.month}${yearly ? '' : '月'}',
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
