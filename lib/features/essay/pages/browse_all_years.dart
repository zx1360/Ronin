import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:torrid/features/essay/models/year_summary.dart';
import 'package:torrid/features/essay/models/essay.dart';
import 'package:torrid/features/essay/pages/detail_page.dart';
import 'package:torrid/features/essay/providers/setting_provider.dart';
import 'package:torrid/features/essay/providers/status_provider.dart';
import 'package:torrid/core/widgets/file_img_builder/file_img_builder.dart';
import 'package:torrid/core/models/mood.dart';

/// 展示所有年份随笔的"-1页"
class BrowseAllYears extends ConsumerStatefulWidget {
  final List<YearSummary> yearSummaries;
  const BrowseAllYears({super.key, required this.yearSummaries});

  @override
  ConsumerState<BrowseAllYears> createState() => BrowseAllYearsState();
}

class BrowseAllYearsState extends ConsumerState<BrowseAllYears> {
  final ScrollController _scrollController = ScrollController();

  /// 获取 ScrollController 供外部使用（如滚动到顶部）
  ScrollController get scrollController => _scrollController;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final essaysAsync = ref.watch(filteredEssaysProvider);
    ref.watch(contentServerProvider); // 防止contentServerProvider被销毁.

    return essaysAsync.when(
      error: (error, stack) => Center(child: Text('加载失败：$error')),
      loading: () => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _AllYearsSummaryCard(yearSummaries: widget.yearSummaries),
          ),
          const Center(child: CircularProgressIndicator()),
        ],
      ),
      data: (essays) => ListView.builder(
        controller: _scrollController,
        shrinkWrap: true,
        itemCount: essays.length + 2,
        itemBuilder: (context, index) {
          // 全年度概览
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: _AllYearsSummaryCard(yearSummaries: widget.yearSummaries),
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
            child: _EssayCardWithYear(
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
}

/// 带有年份显示的随笔卡片（用于全部随笔页面）
class _EssayCardWithYear extends ConsumerWidget {
  final Essay essay;
  final VoidCallback onTap;

  const _EssayCardWithYear({required this.essay, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idMap = ref.watch(idMapProvider);

    // 显示完整日期：yyyy年MM月dd日
    final dateFormat = DateFormat('yyyy年MM月dd日');
    final labelNames = essay.labels.map((l) => idMap[l] ?? "").toList();

    // 内容预览（最多显示3行）
    String previewText = essay.content.replaceAll('\n', ' ');
    if (previewText.length > 100) {
      previewText = '${previewText.substring(0, 100)}...';
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.0),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 日期和标签
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dateFormat.format(essay.date),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                if (labelNames.isNotEmpty)
                  Row(
                    children: labelNames
                        .map(
                          (label) => Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Text(
                              label,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context).primaryColor,
                                  ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // 内容预览
            Text(
              previewText,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 12),

            // 图片预览
            if (essay.imgs.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  children: [
                    ...essay.imgs
                        .take(3)
                        .map(
                          (i) => ClipRRect(
                            borderRadius: BorderRadius.circular(8.0),
                            child: FileImageBuilder(relativeImagePath: i),
                          ),
                        ),
                    if (essay.imgs.length > 3)
                      Container(
                        margin: const EdgeInsets.only(left: 4.0),
                        child: Text(
                          '+${essay.imgs.length - 3}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            const SizedBox(height: 8),

            // 底部信息：心情和字数
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (essay.mood != null)
                  Row(
                    children: [
                      Text(
                        essay.mood!.emoji,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        essay.mood!.label,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  )
                else
                  const SizedBox(),
                Text(
                  '${essay.wordCount} 字',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 所有年份的汇总卡片
class _AllYearsSummaryCard extends StatelessWidget {
  final List<YearSummary> yearSummaries;

  const _AllYearsSummaryCard({required this.yearSummaries});

  @override
  Widget build(BuildContext context) {
    // 计算总体统计数据
    final totalEssayCount = yearSummaries.fold<int>(
      0,
      (sum, y) => sum + y.essayCount,
    );
    final totalWordCount = yearSummaries.fold<int>(
      0,
      (sum, y) => sum + y.wordCount,
    );
    final wordAvg =
        totalEssayCount > 0 ? (totalWordCount / totalEssayCount).round() : 0;
    final yearCount = yearSummaries.length;

    // 找出写作最多的年份
    final mostProductiveYear = yearSummaries.isNotEmpty
        ? yearSummaries.reduce(
            (a, b) => a.essayCount > b.essayCount ? a : b,
          )
        : null;

    return Container(
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
            children: [
              Icon(
                Icons.library_books_outlined,
                color: Theme.of(context).primaryColor,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                '全部随笔',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 主要统计数据
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                context,
                value: totalEssayCount.toString(),
                label: '总篇数',
              ),
              _buildStatItem(
                context,
                value: totalWordCount.toString(),
                label: '总字数',
              ),
              _buildStatItem(
                context,
                value: wordAvg.toString(),
                label: '单篇平均',
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 次要统计数据
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                context,
                value: yearCount.toString(),
                label: '跨越年份',
                isSecondary: true,
              ),
              if (mostProductiveYear != null)
                _buildStatItem(
                  context,
                  value: mostProductiveYear.year,
                  label: '最高产年份',
                  isSecondary: true,
                ),
              if (mostProductiveYear != null)
                _buildStatItem(
                  context,
                  value: mostProductiveYear.essayCount.toString(),
                  label: '该年篇数',
                  isSecondary: true,
                ),
            ],
          ),

          const SizedBox(height: 20),

          // 年度分布图表
          Column(
            children: [
              Text(
                '年度写作分布',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 12),
              _buildYearlyChart(context),
            ],
          ),
        ],
      ),
    );
  }

  // 构建统计项
  Widget _buildStatItem(
    BuildContext context, {
    required String value,
    required String label,
    bool isSecondary = false,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: isSecondary
              ? Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).primaryColor.withAlpha(200),
                  )
              : Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).primaryColor,
                  ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  // 构建年度分布图表（支持多行，每行最多12年）
  Widget _buildYearlyChart(BuildContext context) {
    if (yearSummaries.isEmpty) {
      return const SizedBox(height: 60);
    }

    // 按年份排序（升序，方便从左到右展示时间线）
    final sortedSummaries = List<YearSummary>.from(yearSummaries)
      ..sort((a, b) => a.year.compareTo(b.year));

    final maxCount = sortedSummaries
        .map((y) => y.essayCount)
        .reduce((a, b) => a > b ? a : b);

    // 每行最多12个年份
    const maxPerRow = 12;
    final rowCount = (sortedSummaries.length / maxPerRow).ceil();
    
    // 将年份分成多行
    final List<List<YearSummary>> rows = [];
    for (int i = 0; i < rowCount; i++) {
      final start = i * maxPerRow;
      final end = (start + maxPerRow).clamp(0, sortedSummaries.length);
      rows.add(sortedSummaries.sublist(start, end));
    }

    return Column(
      children: rows.asMap().entries.map((entry) {
        final rowIndex = entry.key;
        final rowSummaries = entry.value;
        final isLastRow = rowIndex == rows.length - 1;
        
        return Padding(
          padding: EdgeInsets.only(bottom: isLastRow ? 0 : 12),
          child: SizedBox(
            height: 80,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: rowSummaries.map((summary) {
                final heightRatio = maxCount > 0 ? summary.essayCount / maxCount : 0.0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          summary.essayCount.toString(),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.grey[600],
                            fontSize: 9,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          height: 40 * heightRatio + 4,
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withAlpha(
                              (150 + 105 * heightRatio).round(),
                            ),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          summary.year.length >= 4 
                              ? summary.year.substring(2) // 只显示后两位年份
                              : summary.year,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.grey[600],
                            fontSize: 10,
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
      }).toList(),
    );
  }
}
