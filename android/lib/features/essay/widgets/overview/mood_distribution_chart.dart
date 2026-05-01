import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:torrid/core/models/mood.dart';

/// 心情分布图（含饼状图）
class MoodDistributionChart extends StatelessWidget {
  final Map<MoodType, int> moodStats;

  const MoodDistributionChart({super.key, required this.moodStats});

  @override
  Widget build(BuildContext context) {
    if (moodStats.isEmpty) {
      return const SizedBox.shrink();
    }

    final total = moodStats.values.fold(0, (sum, count) => sum + count);

    // 按数量排序
    final sortedMoods = moodStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

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
          // 心情分布饼状图
          SizedBox(
            height: 160,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 左侧：饼状图
                SizedBox(
                  width: 140,
                  height: 140,
                  child: CustomPaint(
                    painter: _PieChartPainter(
                      moodStats: sortedMoods,
                      total: total,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            total.toString(),
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                          ),
                          Text(
                            '条记录',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Colors.grey[600],
                                  fontSize: 11,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                // 右侧：心情列表图例
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: sortedMoods.take(5).map((entry) {
                      final mood = entry.key;
                      final count = entry.value;
                      final percentage = (count / total * 100).toStringAsFixed(
                        1,
                      );

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            // 颜色标记
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: mood.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              mood.emoji,
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                mood.label,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(fontWeight: FontWeight.w500),
                              ),
                            ),
                            Text(
                              '$percentage%',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: mood.color,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 心情条形分布
          Row(
            children: sortedMoods.map((entry) {
              final mood = entry.key;
              final count = entry.value;
              final ratio = count / total;

              return Expanded(
                flex: (ratio * 100).round().clamp(1, 100),
                child: Tooltip(
                  message:
                      '${mood.label}: $count (${(ratio * 100).toStringAsFixed(1)}%)',
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: mood.color,
                      borderRadius: sortedMoods.first == entry
                          ? const BorderRadius.horizontal(
                              left: Radius.circular(4),
                            )
                          : sortedMoods.last == entry
                          ? const BorderRadius.horizontal(
                              right: Radius.circular(4),
                            )
                          : null,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// 饼状图绘制器
class _PieChartPainter extends CustomPainter {
  final List<MapEntry<MoodType, int>> moodStats;
  final int total;

  _PieChartPainter({required this.moodStats, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final innerRadius = radius * 0.55; // 内圆半径，形成环形

    double startAngle = -math.pi / 2; // 从顶部开始

    for (final entry in moodStats) {
      final mood = entry.key;
      final count = entry.value;
      final sweepAngle = (count / total) * 2 * math.pi;

      final paint = Paint()
        ..color = mood.color
        ..style = PaintingStyle.fill;

      // 绘制扇形
      final path = Path()
        ..moveTo(
          center.dx + innerRadius * math.cos(startAngle),
          center.dy + innerRadius * math.sin(startAngle),
        )
        ..lineTo(
          center.dx + radius * math.cos(startAngle),
          center.dy + radius * math.sin(startAngle),
        )
        ..arcTo(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweepAngle,
          false,
        )
        ..lineTo(
          center.dx + innerRadius * math.cos(startAngle + sweepAngle),
          center.dy + innerRadius * math.sin(startAngle + sweepAngle),
        )
        ..arcTo(
          Rect.fromCircle(center: center, radius: innerRadius),
          startAngle + sweepAngle,
          -sweepAngle,
          false,
        )
        ..close();

      canvas.drawPath(path, paint);

      // 添加扇形间的细线分隔
      if (moodStats.length > 1) {
        final linePaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;

        canvas.drawLine(
          Offset(
            center.dx + innerRadius * math.cos(startAngle),
            center.dy + innerRadius * math.sin(startAngle),
          ),
          Offset(
            center.dx + radius * math.cos(startAngle),
            center.dy + radius * math.sin(startAngle),
          ),
          linePaint,
        );
      }

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
