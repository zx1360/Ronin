import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/booklet/models/style.dart';
import 'package:torrid/features/booklet/providers/providers.dart';
import 'package:torrid/features/booklet/widgets/routine/overview/constants/global_constants.dart';

/// 构建Style下拉选择框（支持滚动，按创建时间倒序）
/// [currentStyle]：当前选中的样式
/// [onStyleChanged]：样式切换回调
class StyleDropdown extends ConsumerWidget {
  final Style? currentStyle;
  final void Function(String?) onStyleChanged;
  const StyleDropdown({
    super.key,
    required this.currentStyle,
    required this.onStyleChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (currentStyle == null) {
      return Text('暂无打卡计划', style: noteSmall);
    }

    final allStyles = ref.watch(sortedStylesProvider);
    return LimitedBox(
      maxHeight: dropdownMaxHeight,
      child: DropdownButtonFormField<String>(
        initialValue: currentStyle!.id,
        items: allStyles.map((style) {
          final startDateStr = fullDateFormatter
              .format(style.startDate)
              .split(' ')[0];
          return DropdownMenuItem<String>(
            value: style.id,
            child: Text(
              '$startDateStr 打卡计划',
              style: noteText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        onChanged: onStyleChanged,
        decoration: InputDecoration(
          labelText: '选择打卡计划',
          labelStyle: noteSmall,
          border: const OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFFD4C8B8)),
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
        ),
        style: noteText,
        icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF8B5A2B)),
        iconSize: 20,
        isExpanded: true,
        dropdownColor: const Color(0xFFF5F0E1),
        menuMaxHeight: dropdownMaxHeight,
      ),
    );
  }
}

/// 构建单个统计项（概览卡片内部使用）
/// [title]：统计项标题
/// [value]：统计项数值
Widget buildStatItem(String title, String value) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: noteSmall),
      const SizedBox(height: 2),
      Text(
        value,
        style: noteText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ],
  );
}

/// 构建打卡计划信息卡片（展示核心统计数据）
/// [currentStyle]：当前选中的样式（为空时不显示）
class CompactStyleOverview extends ConsumerWidget {
  final Style? currentStyle;
  const CompactStyleOverview({super.key, required this.currentStyle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (currentStyle == null) return const SizedBox.shrink();

    final currentStreak = ref.watch(currentStreakProvider(currentStyle!.id));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0E1),
        border: Border.all(color: const Color(0xFFD4C8B8)),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.withAlpha(20),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('打卡计划概览', style: noteTitle),
              const Spacer(),
              // 当前连续打卡高亮
              if (currentStreak > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: currentStreak >= 7
                        ? Colors.orange.shade100
                        : Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: currentStreak >= 7
                          ? Colors.orange.shade400
                          : Colors.amber.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_fire_department,
                        size: 14,
                        color: currentStreak >= 7
                            ? Colors.deepOrange
                            : Colors.orange,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '连续 $currentStreak 天',
                        style: noteSmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: currentStreak >= 7
                              ? Colors.deepOrange.shade700
                              : Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const Divider(color: Color(0xFFD4C8B8), height: 12, thickness: 0.8),

          // 统计数据网格
          GridView.count(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            padding: EdgeInsets.only(top: 5, left: 5, right: 5),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 8,
            childAspectRatio: 4,
            children: [
              buildStatItem('有效打卡', '${currentStyle!.validCheckIn} 天'),
              buildStatItem('全完成', '${currentStyle!.fullyDone} 次'),
              buildStatItem('最长连续', '${currentStyle!.longestStreak} 天'),
              buildStatItem('最长全完成', '${currentStyle!.longestFullyStreak} 天'),
            ],
          ),
        ],
      ),
    );
  }
}
