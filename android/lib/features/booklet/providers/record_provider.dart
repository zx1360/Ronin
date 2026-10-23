import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:torrid/features/booklet/models/record.dart';
import 'package:torrid/features/booklet/models/style.dart';
import 'package:torrid/features/booklet/providers/data_source_provider.dart';
import 'package:torrid/features/booklet/providers/style_provider.dart';
import 'package:torrid/core/utils/util.dart';

part 'record_provider.g.dart';

/// 根据 styleId 返回关联的倒序排列的所有 Records
@riverpod
List<Record> recordsByStyleId(RecordsByStyleIdRef ref, String styleId) {
  final allRecords = ref.watch(allRecordsProvider);
  return allRecords.where((item) => item.styleId == styleId).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
}

/// 根据日期获取 Record
@riverpod
Record? recordByDate(RecordByDateRef ref, {required DateTime targetDate}) {
  final todayStyle = ref.watch(latestStyleProvider);
  if (todayStyle == null) return null;

  final allRecords = ref.watch(allRecordsProvider);
  return allRecords
      .where(
        (item) =>
            item.styleId == todayStyle.id && isSameDay(item.date, targetDate),
      )
      .firstOrNull;
}

/// 各任务的完成次数，忽略不属于该计划的任务。
@riverpod
Map<String, int> allTaskCompletionCounts(
  AllTaskCompletionCountsRef ref,
  String styleId,
) {
  final records = ref.watch(recordsByStyleIdProvider(styleId));
  final style = ref.watch(styleByIdProvider(styleId));

  if (style == null) return {};

  final Map<String, int> counts = {};
  for (final task in style.tasks) {
    counts[task.id] = 0;
  }

  for (final record in records) {
    for (final entry in record.taskCompletion.entries) {
      if (entry.value == true && counts.containsKey(entry.key)) {
        counts[entry.key] = counts[entry.key]! + 1;
      }
    }
  }

  return counts;
}

/// 截至今天或昨天的连续打卡天数；两天均未打卡则为 0。
@riverpod
int currentStreak(CurrentStreakRef ref, String styleId) {
  final currentRecords = ref.watch(recordsByStyleIdProvider(styleId));
  if (currentRecords.isEmpty) return 0;

  final currentDates = currentRecords.map((r) => dateOnly(r.date)).toSet();
  final todayDate = getTodayDate();
  final yesterdayDate = todayDate.subtract(const Duration(days: 1));

  final hasTodayRecord = currentDates.contains(todayDate);
  final hasYesterdayRecord = currentDates.contains(dateOnly(yesterdayDate));

  if (!hasTodayRecord && !hasYesterdayRecord) return 0;

  int streak = 0;
  DateTime currentDate = hasTodayRecord ? todayDate : yesterdayDate;
  while (currentDates.contains(dateOnly(currentDate))) {
    streak++;
    currentDate = currentDate.subtract(const Duration(days: 1));
  }
  return streak;
}

/// 根据 Style 获取该 Style 的日期范围
@riverpod
DateTimeRange? styleDateRange(StyleDateRangeRef ref, {required Style? style}) {
  if (style == null) return null;

  final records = ref.watch(recordsByStyleIdProvider(style.id));
  if (records.isEmpty) {
    return DateTimeRange(start: getTodayDate(), end: getTodayDate());
  }

  final earliestDate = dateOnly(records.last.date);
  return DateTimeRange(start: earliestDate, end: getTodayDate());
}
