import 'dart:math';

import 'package:torrid/core/utils/util.dart';
import 'package:torrid/features/booklet/models/record.dart';

/// ============================================================================
/// 打卡统计通用函数
///
/// 供 RoutineService 等业务层复用，避免各文件重复实现私有版本。
/// 所有"日期"均按日历日（dateOnly）比较，与 record.date 的语义一致。
/// ============================================================================

/// 计算完全完成（所有任务均勾选）的天数
int countFullyDone(List<Record> records) {
  return records
      .where((record) => record.taskCompletion.values.every((flag) => flag))
      .length;
}

/// 计算最长连续天数（输入已规整为日期的升序列表）
int longestConsecutiveDays(List<DateTime> sortedDates) {
  if (sortedDates.isEmpty) return 0;

  int maxStreak = 1;
  int currentStreak = 1;

  for (int i = 1; i < sortedDates.length; i++) {
    final dayDiff = sortedDates[i].difference(sortedDates[i - 1]).inDays;
    if (dayDiff == 1) {
      currentStreak++;
      maxStreak = max(maxStreak, currentStreak);
    } else {
      currentStreak = 1;
    }
  }
  return maxStreak;
}

/// 计算最长连续打卡天数（不要求全完成）
int longestStreak(List<Record> records) {
  final sortedDates = records.map((r) => dateOnly(r.date)).toList()..sort();
  return longestConsecutiveDays(sortedDates);
}

/// 计算最长连续"全完成"天数
int longestFullyStreak(List<Record> records) {
  final fullyDoneDates =
      records
          .where((r) => r.taskCompletion.values.every((v) => v))
          .map((r) => dateOnly(r.date))
          .toList()
        ..sort();
  return longestConsecutiveDays(fullyDoneDates);
}
