import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:torrid/app/theme/theme_book.dart';
import 'package:torrid/core/models/mood.dart';
import 'package:torrid/features/essay/models/essay.dart';
import 'package:torrid/features/essay/models/year_summary.dart';
import 'package:torrid/features/essay/providers/status_provider.dart';
import 'package:torrid/features/essay/widgets/overview/label_distribution_chart.dart';
import 'package:torrid/features/essay/widgets/overview/mood_distribution_chart.dart';
import 'package:torrid/features/essay/widgets/overview/monthly_trend_chart.dart';
import 'package:torrid/features/essay/widgets/overview/writing_stats_card.dart';

/// 年度/全部概览页面
class YearOverviewPage extends ConsumerWidget {
  final YearSummary summary;

  /// 是否为全部年份概览（year == "-1"）
  bool get isAllYears => summary.year == '-1';

  const YearOverviewPage({super.key, required this.summary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 获取该年份（或全部）的随笔列表
    // 注意："-1" 表示全部年份，需要使用 filteredEssaysProvider
    final essaysAsync = isAllYears
        ? ref.watch(filteredEssaysProvider)
        : ref.watch(yearEssaysProvider(year: summary.year));

    final title = isAllYears ? '全部随笔概览' : '${summary.year}年度概览';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceContainer,
        foregroundColor: AppTheme.onSurface,
        elevation: 1,
        titleTextStyle: Theme.of(
          context,
        ).appBarTheme.titleTextStyle?.copyWith(color: AppTheme.onSurface),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(color: AppTheme.outline.withAlpha(77), height: 1),
        ),
        title: Text(title),
      ),
      body: essaysAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('加载失败：$error')),
        data: (essays) => _buildContent(context, ref, essays),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List<Essay> essays,
  ) {
    final labels = ref.watch(labelsProvider);
    final idMap = ref.watch(idMapProvider);

    // 计算统计数据
    final stats = _calculateStats(essays, idMap);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 写作统计卡片
          WritingStatsCard(
            isAllYears: isAllYears,
            summary: summary,
            essays: essays,
            stats: stats,
          ),

          const SizedBox(height: 20),

          // 月度趋势图（仅单年份显示）
          if (!isAllYears) ...[
            _buildSectionTitle(context, '月度写作趋势'),
            const SizedBox(height: 12),
            MonthlyTrendChart(monthSummaries: summary.monthSummaries),
            const SizedBox(height: 20),
          ],

          // 全部年份显示年度趋势
          if (isAllYears) ...[
            _buildSectionTitle(context, '年度写作趋势'),
            const SizedBox(height: 12),
            _buildYearlyTrendChart(context, ref),
            const SizedBox(height: 20),
          ],

          // 标签分布
          _buildSectionTitle(context, '标签分布'),
          const SizedBox(height: 12),
          LabelDistributionChart(essays: essays, labels: labels, idMap: idMap),

          const SizedBox(height: 20),

          // 心情分布（如果有心情数据）
          if (stats['moodCount'] > 0) ...[
            _buildSectionTitle(context, '心情记录'),
            const SizedBox(height: 12),
            MoodDistributionChart(moodStats: stats['moodStats']),
            const SizedBox(height: 20),
          ],

          // 写作习惯统计
          _buildSectionTitle(context, '写作习惯'),
          const SizedBox(height: 12),
          _buildWritingHabits(context, stats),

          // 底部间距
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildYearlyTrendChart(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(summariesProvider);
    // 过滤掉 "-1" 并按年份排序
    final yearSummaries = summaries.where((s) => s.year != '-1').toList()
      ..sort((a, b) => int.parse(a.year).compareTo(int.parse(b.year)));

    if (yearSummaries.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }

    final maxWordCount = yearSummaries.fold(
      0,
      (max, s) => s.wordCount > max ? s.wordCount : max,
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
      child: SizedBox(
        height: 160,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: yearSummaries.map((s) {
            final heightRatio = maxWordCount > 0
                ? s.wordCount / maxWordCount
                : 0.0;

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // 字数
                    Text(
                      _formatNumber(s.wordCount),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 9,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    // 柱状图
                    Container(
                      width: double.infinity,
                      height: heightRatio * 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Theme.of(context).primaryColor.withAlpha(178),
                            Theme.of(context).primaryColor.withAlpha(102),
                          ],
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 年份标签
                    Text(
                      s.year,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildWritingHabits(BuildContext context, Map<String, dynamic> stats) {
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
          _buildHabitRow(
            context,
            icon: Icons.wb_sunny_outlined,
            label: '最常写作月份',
            value: stats['peakMonth'] ?? '暂无数据',
          ),
          const Divider(height: 24),
          _buildHabitRow(
            context,
            icon: Icons.calendar_today_outlined,
            label: '最常写作星期',
            value: stats['peakWeekday'] ?? '暂无数据',
          ),
          const Divider(height: 24),
          _buildHabitRow(
            context,
            icon: Icons.edit_note,
            label: '最长随笔',
            value: '${stats['maxWords']} 字',
          ),
          const Divider(height: 24),
          _buildHabitRow(
            context,
            icon: Icons.short_text,
            label: '最短随笔',
            value: '${stats['minWords']} 字',
          ),
        ],
      ),
    );
  }

  Widget _buildHabitRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).primaryColor),
        const SizedBox(width: 12),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).primaryColor,
          ),
        ),
      ],
    );
  }

  /// 计算各种统计数据
  Map<String, dynamic> _calculateStats(
    List<Essay> essays,
    Map<String, String> idMap,
  ) {
    if (essays.isEmpty) {
      return {
        'peakMonth': null,
        'peakWeekday': null,
        'maxWords': 0,
        'minWords': 0,
        'moodCount': 0,
        'moodStats': <MoodType, int>{},
      };
    }

    // 月份统计
    final monthCounts = <int, int>{};
    for (final essay in essays) {
      monthCounts[essay.month] = (monthCounts[essay.month] ?? 0) + 1;
    }
    final peakMonth = monthCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    // 星期统计
    final weekdayCounts = <int, int>{};
    for (final essay in essays) {
      final weekday = essay.date.weekday;
      weekdayCounts[weekday] = (weekdayCounts[weekday] ?? 0) + 1;
    }
    final peakWeekday = weekdayCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    // 字数统计
    final maxWords = essays.fold(
      0,
      (max, e) => e.wordCount > max ? e.wordCount : max,
    );
    final minWords = essays.fold(
      essays.first.wordCount,
      (min, e) => e.wordCount < min ? e.wordCount : min,
    );

    // 心情统计
    final moodStats = <MoodType, int>{};
    int moodCount = 0;
    for (final essay in essays) {
      if (essay.mood != null) {
        moodStats[essay.mood!] = (moodStats[essay.mood!] ?? 0) + 1;
        moodCount++;
      }
    }

    return {
      'peakMonth': '$peakMonth月',
      'peakWeekday': _weekdayName(peakWeekday),
      'maxWords': maxWords,
      'minWords': minWords,
      'moodCount': moodCount,
      'moodStats': moodStats,
    };
  }

  String _weekdayName(int weekday) {
    const names = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return names[weekday];
  }

  String _formatNumber(int number) {
    if (number >= 10000) {
      return '${(number / 10000).toStringAsFixed(1)}万';
    }
    return number.toString();
  }
}
