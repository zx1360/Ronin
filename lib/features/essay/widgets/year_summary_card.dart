import 'package:flutter/material.dart';
import 'package:torrid/features/essay/models/year_summary.dart';

class YearSummaryCard extends StatelessWidget {
  final YearSummary yearSummary;

  const YearSummaryCard({super.key, required this.yearSummary});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 年份和总数
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${yearSummary.year} 年',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  '共 ${yearSummary.essayCount} 篇 · ${yearSummary.wordCount} 字',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 月度数据
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.8,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: yearSummary.monthSummaries.length,
              itemBuilder: (context, index) {
                final monthSummary = yearSummary.monthSummaries[index];
                // TODO: 点击跳转返回到essay_browse_page, 转到该月的第一篇随笔处.
                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.only(right: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Text(
                            '${monthSummary.month} 月',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          Text(
                            '${monthSummary.essayCount} 篇',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${monthSummary.wordCount} 字',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
