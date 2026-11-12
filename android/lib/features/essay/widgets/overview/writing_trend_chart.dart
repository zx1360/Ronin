import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:torrid/features/essay/models/year_summary.dart';

class WritingTrendChart extends StatelessWidget {
  final List<MonthSummary> periods;
  final bool yearly;

  const WritingTrendChart({
    super.key,
    required this.periods,
    this.yearly = false,
  });

  static const double _plotHeight = 100;
  static const double _dotSize = 8;

  @override
  Widget build(BuildContext context) {
    if (periods.isEmpty) return const Center(child: Text('暂无数据'));

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final barColor = colors.primary.withValues(alpha: 0.76);
    final dotColor = theme.brightness == Brightness.dark
        ? Colors.orange.shade300
        : const Color(0xFFC97D37);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final minWidth = yearly
        ? MediaQuery.textScalerOf(context).scale(40) * periods.length
        : 0.0;

    final maxWords = periods.fold(1, (n, p) => math.max(n, p.wordCount));
    final maxEssays = periods.fold(1, (n, p) => math.max(n, p.essayCount));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            _legend('字数', barColor, labelStyle),
            _legend('篇数', dotColor, labelStyle, dot: true),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = math.max(constraints.maxWidth, minWidth);
            final barWidth = math.min(28.0, width / periods.length * 0.64);
            final chart = SizedBox(
              width: width,
              child: Stack(
                children: [
                  Positioned(
                    top: _plotHeight - 1,
                    left: 0,
                    right: 0,
                    child: Divider(height: 1, color: colors.outlineVariant),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final period in periods)
                        Expanded(
                          child: Tooltip(
                            message:
                                '${period.month}${yearly ? '年' : '月'}\n'
                                '${period.essayCount} 篇 · ${period.wordCount} 字',
                            child: Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  height: _plotHeight,
                                  child: Stack(
                                    alignment: Alignment.bottomCenter,
                                    children: [
                                      Container(
                                        width: barWidth,
                                        height:
                                            period.wordCount /
                                            maxWords *
                                            (_plotHeight - _dotSize / 2),
                                        decoration: BoxDecoration(
                                          color: barColor,
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                top: Radius.circular(4),
                                              ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom:
                                            period.essayCount /
                                            maxEssays *
                                            (_plotHeight - _dotSize),
                                        child: Container(
                                          width: _dotSize,
                                          height: _dotSize,
                                          decoration: BoxDecoration(
                                            color: dotColor,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: colors.surface,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(period.month, style: labelStyle),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
            if (width <= constraints.maxWidth) return chart;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: chart,
            );
          },
        ),
      ],
    );
  }

  Widget _legend(
    String label,
    Color color,
    TextStyle? style, {
    bool dot = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: dot ? _dotSize : 10,
          height: dot ? _dotSize : 12,
          decoration: BoxDecoration(
            color: color,
            shape: dot ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: dot ? null : BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: style),
      ],
    );
  }
}
