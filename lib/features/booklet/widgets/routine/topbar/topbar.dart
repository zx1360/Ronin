import 'package:flutter/material.dart';
import 'package:torrid/features/booklet/widgets/routine/topbar/stat_item.dart';

// 统计信息卡片组件.
class Topbar extends StatelessWidget {
  const Topbar({super.key, required this.stats});

  final Map<String, dynamic> stats;

  @override
  Widget build(BuildContext context) {
    // 判断stats是否为空
    final bool isStatsEmpty = stats.isEmpty;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.yellow.shade100,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.yellow.shade200.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      // 根据stats是否为空显示不同内容
      child: isStatsEmpty
          ? Center(
              child: Text(
                "点击以新建样式",
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                StatItem(
                  label: "累计打卡",
                  value: "${stats["validCheckIn"]}天",
                  icon: Icons.calendar_today,
                ),
                StatItem(
                  label: "全通天数",
                  value: "${stats["fullyDone"]}天",
                  icon: Icons.star,
                ),
                StatItem(
                  label: "当前连续",
                  value: "${stats["latest_streak"]}天",
                  icon: Icons.fireplace,
                ),
              ],
            ),
    );
  }
}
