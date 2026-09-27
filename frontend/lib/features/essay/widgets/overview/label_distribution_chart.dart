import 'package:flutter/material.dart';
import 'package:torrid/features/essay/models/essay.dart';
import 'package:torrid/features/essay/models/label.dart';

/// 标签分布图
class LabelDistributionChart extends StatelessWidget {
  final List<Essay> essays;
  final List<Label> labels;
  final Map<String, String> idMap;

  const LabelDistributionChart({
    super.key,
    required this.essays,
    required this.labels,
    required this.idMap,
  });

  @override
  Widget build(BuildContext context) {
    // 统计每个标签的使用次数
    final labelCounts = <String, int>{};
    for (final essay in essays) {
      for (final labelId in essay.labels) {
        labelCounts[labelId] = (labelCounts[labelId] ?? 0) + 1;
      }
    }

    if (labelCounts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            '暂无标签数据',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
          ),
        ),
      );
    }

    // 排序并取前10个
    final sortedLabels = labelCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topLabels = sortedLabels.take(10).toList();
    final maxCount = topLabels.first.value;

    // 预定义的颜色列表
    final colors = [
      const Color(0xFF8B5A2B),
      const Color(0xFFA3D9A5),
      const Color(0xFF6B8E23),
      const Color(0xFFCD853F),
      const Color(0xFF5F9EA0),
      const Color(0xFFD2691E),
      const Color(0xFF708090),
      const Color(0xFF9ACD32),
      const Color(0xFFBC8F8F),
      const Color(0xFF8FBC8F),
    ];

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
          // 标签分布条
          ...topLabels.asMap().entries.map((entry) {
            final index = entry.key;
            final labelId = entry.value.key;
            final count = entry.value.value;
            final labelName = idMap[labelId] ?? '未知标签';
            final ratio = count / maxCount;
            final color = colors[index % colors.length];

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  // 标签名
                  SizedBox(
                    width: 70,
                    child: Text(
                      labelName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 进度条
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.grey.withAlpha(51),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: ratio,
                          child: Container(
                            height: 20,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 数量
                  SizedBox(
                    width: 30,
                    child: Text(
                      count.toString(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            );
          }),

          // 显示更多提示
          if (sortedLabels.length > 10) ...[
            const SizedBox(height: 8),
            Text(
              '共 ${sortedLabels.length} 个标签，显示前 10 个',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[500],
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
