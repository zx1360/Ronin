import 'package:flutter/material.dart';
import 'package:torrid/features/essay/models/year_summary.dart';

/// 年度概览卡片组件
/// 点击可进入详细概览页面，显示更多统计信息
class YearSummaryCard extends StatelessWidget {
  final YearSummary summary;
  final VoidCallback? onTap;

  const YearSummaryCard({super.key, required this.summary, this.onTap});

  @override
  Widget build(BuildContext context) {
    // 计算每篇平均字数
    final wordAvg = summary.essayCount > 0
        ? (summary.wordCount / summary.essayCount).round()
        : 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(48),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    summary.year == '-1' ? '全部随笔' : '${summary.year} 年',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (onTap != null)
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Colors.grey[400],
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // 统计数据
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    context,
                    value: summary.essayCount.toString(),
                    label: '总篇数',
                  ),
                  _buildStatItem(
                    context,
                    value: summary.wordCount.toString(),
                    label: '总字数',
                  ),
                  _buildStatItem(
                    context,
                    value: wordAvg.toString(),
                    label: '单篇平均',
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 月度数据图表
              Column(
                children: [
                  Text(
                    '月度写作趋势',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  _buildMonthlyChart(context),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 构建统计项
  Widget _buildStatItem(
    BuildContext context, {
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }

  // 构建月度图表
  Widget _buildMonthlyChart(BuildContext context) {
    // 找到最大字数，用于计算高度比例
    final maxWordCount = summary.monthSummaries.isNotEmpty
        ? summary.monthSummaries.fold(
            0,
            (max, month) => month.wordCount > max ? month.wordCount : max,
          )
        : 1;

    return SizedBox(
      height: 120,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: summary.monthSummaries.map((month) {
          // 计算高度比例
          final heightRatio = maxWordCount > 0
              ? month.wordCount / maxWordCount
              : 0;

          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // 柱状图
              Container(
                width: 12,
                height: heightRatio * 100, // 最大高度100%
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withAlpha(178),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4.0),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // 月份标签
              Text(
                '${month.month}月',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
