import 'package:flutter/material.dart';
import 'package:torrid/features/essay/models/year_summary.dart';

/// 月度写作趋势图
class MonthlyTrendChart extends StatelessWidget {
  final List<MonthSummary> monthSummaries;

  const MonthlyTrendChart({super.key, required this.monthSummaries});

  @override
  Widget build(BuildContext context) {
    // 创建完整的12个月数据
    final fullMonthData = List.generate(12, (index) {
      final month = index + 1;
      final existing = monthSummaries.where(
        (m) => int.tryParse(m.month) == month,
      );
      if (existing.isNotEmpty) {
        return existing.first;
      }
      return MonthSummary(month: month.toString(), essayCount: 0, wordCount: 0);
    });

    final maxWordCount = fullMonthData.fold(
      1,
      (max, m) => m.wordCount > max ? m.wordCount : max,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 图例
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegend(context, '字数', Theme.of(context).primaryColor),
              const SizedBox(width: 20),
              _buildLegend(context, '篇数', Colors.orange),
            ],
          ),
          const SizedBox(height: 16),
          // 图表
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: fullMonthData.map((month) {
                final wordRatio = maxWordCount > 0
                    ? month.wordCount / maxWordCount
                    : 0.0;
                final essayRatio = month.essayCount > 0
                    ? (month.essayCount / 10).clamp(0.1, 1.0)
                    : 0.0;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // 篇数指示点
                        if (month.essayCount > 0)
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                        SizedBox(height: essayRatio * 30),
                        // 字数柱状图
                        Tooltip(
                          message:
                              '${month.month}月\n字数: ${month.wordCount}\n篇数: ${month.essayCount}',
                          child: Container(
                            width: double.infinity,
                            height: wordRatio * 80,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: month.wordCount > 0
                                    ? [
                                        Theme.of(context).primaryColor,
                                        Theme.of(
                                          context,
                                        ).primaryColor.withAlpha(153),
                                      ]
                                    : [
                                        Colors.grey.withAlpha(51),
                                        Colors.grey.withAlpha(26),
                                      ],
                              ),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // 月份标签
                        Text(
                          '${int.parse(month.month)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontSize: 10,
                                color: month.wordCount > 0
                                    ? Colors.grey[700]
                                    : Colors.grey[400],
                                fontWeight: month.wordCount > 0
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(BuildContext context, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }
}
