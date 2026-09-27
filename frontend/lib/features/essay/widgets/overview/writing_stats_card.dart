import 'package:flutter/material.dart';
import 'package:torrid/features/essay/models/essay.dart';
import 'package:torrid/features/essay/models/year_summary.dart';

/// 写作统计卡片
class WritingStatsCard extends StatelessWidget {
  final bool isAllYears;
  final YearSummary summary;
  final List<Essay> essays;
  final Map<String, dynamic> stats;

  const WritingStatsCard({
    super.key,
    required this.isAllYears,
    required this.summary,
    required this.essays,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    // 计算每篇平均字数
    final wordAvg = summary.essayCount > 0
        ? (summary.wordCount / summary.essayCount).round()
        : 0;

    // 计算写作天数（有随笔的不同日期数）
    final writingDays = essays
        .map((e) => '${e.date.year}-${e.date.month}-${e.date.day}')
        .toSet()
        .length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).primaryColor.withAlpha(230),
            Theme.of(context).primaryColor,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withAlpha(77),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Row(
            children: [
              Icon(
                isAllYears ? Icons.auto_awesome : Icons.calendar_month,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAllYears ? '累计写作' : '${summary.year}年写作',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      isAllYears ? '记录你的每一刻' : '这一年的文字记忆',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withAlpha(204),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 主要统计数据
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMainStat(
                context,
                value: summary.essayCount.toString(),
                label: '总篇数',
                icon: Icons.article_outlined,
              ),
              Container(
                width: 1,
                height: 50,
                color: Colors.white.withAlpha(51),
              ),
              _buildMainStat(
                context,
                value: _formatNumber(summary.wordCount),
                label: '总字数',
                icon: Icons.text_fields,
              ),
              Container(
                width: 1,
                height: 50,
                color: Colors.white.withAlpha(51),
              ),
              _buildMainStat(
                context,
                value: wordAvg.toString(),
                label: '篇均字数',
                icon: Icons.analytics_outlined,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 次要统计数据
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(26),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSubStat(context, '$writingDays', '写作天数'),
                _buildSubStat(
                  context,
                  isAllYears
                      ? '${summary.monthSummaries.length}'
                      : '${summary.monthSummaries.where((m) => m.essayCount > 0).length}',
                  isAllYears ? '跨越年数' : '活跃月份',
                ),
                _buildSubStat(
                  context,
                  essays.where((e) => e.imgs.isNotEmpty).length.toString(),
                  '含图随笔',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainStat(
    BuildContext context, {
    required String value,
    required String label,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withAlpha(204), size: 20),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.white.withAlpha(204)),
        ),
      ],
    );
  }

  Widget _buildSubStat(BuildContext context, String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.white.withAlpha(178),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  String _formatNumber(int number) {
    if (number >= 10000) {
      return '${(number / 10000).toStringAsFixed(1)}万';
    }
    return number.toString();
  }
}
