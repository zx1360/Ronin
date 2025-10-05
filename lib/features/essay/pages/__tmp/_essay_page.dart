import 'package:flutter/material.dart';
import 'package:torrid/features/essay/pages/__tmp/_essay_detail_page.dart';
import 'package:torrid/features/essay/pages/__tmp/_example.dart';
import 'package:torrid/features/essay/pages/__tmp/_essay_card.dart';
import 'package:torrid/features/essay/widgets/year_summary_card.dart';

class EssayDisplayScreen extends StatelessWidget {
  const EssayDisplayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 获取示例数据
    final essays = EssaySampleData.sampleEssays;
    final yearSummaries = EssaySampleData.sampleYearSummaries;

    // 按日期排序（最新的在前）
    essays.sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的随笔'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 年度总结部分
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '写作统计',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 只展示今年的总结
                  YearSummaryCard(summary: yearSummaries.first),
                ],
              ),
            ),

            // 随笔列表部分
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                '我的随笔',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),

            // 随笔列表
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: essays.length,
              itemBuilder: (context, index) {
                final essay = essays[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: EssayCard(
                    essay: essay,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EssayDetailScreen(essay: essay),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 80), // 为浮动按钮留出空间
          ],
        ),
      ),

      // 添加新随笔的按钮
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 这里添加新建随笔的逻辑
        },
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.edit),
      ),
    );
  }
}
