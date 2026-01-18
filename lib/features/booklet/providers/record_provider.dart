import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:torrid/features/booklet/models/record.dart';
import 'package:torrid/features/booklet/models/style.dart';
import 'package:torrid/features/booklet/providers/data_source_provider.dart';
import 'package:torrid/features/booklet/providers/style_provider.dart';
import 'package:torrid/core/utils/util.dart';

part 'record_provider.g.dart';

/// ============================================================================
/// Record 相关的 Providers
/// 提供 Record 数据的查询和派生数据
/// ============================================================================

// ==================== Record 查询 Providers ====================

/// 根据 styleId 返回关联的倒序排列的所有 Records
@riverpod
List<Record> recordsByStyleId(RecordsByStyleIdRef ref, String styleId) {
  final allRecords = ref.watch(allRecordsProvider);
  return allRecords.where((item) => item.styleId == styleId).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
}

/// 获取今天的 Record（最近的 Style），无则返回 null
@riverpod
Record? todayRecord(TodayRecordRef ref) {
  final todayStyle = ref.watch(latestStyleProvider);
  if (todayStyle == null) return null;

  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);
  final allRecords = ref.watch(allRecordsProvider);

  final todayRecords = allRecords
      .where(
        (item) =>
            item.styleId == todayStyle.id && isSameDay(item.date, todayDate),
      )
      .toList();

  return todayRecords.isNotEmpty ? todayRecords.first : null;
}

/// 根据日期获取 Record
@riverpod
Record? recordByDate(RecordByDateRef ref, {required DateTime targetDate}) {
  final todayStyle = ref.watch(latestStyleProvider);
  if (todayStyle == null) return null;

  final allRecords = ref.watch(allRecordsProvider);
  final targetRecords = allRecords
      .where(
        (item) =>
            item.styleId == todayStyle.id && isSameDay(item.date, targetDate),
      )
      .toList();

  return targetRecords.isNotEmpty ? targetRecords.first : null;
}

// ==================== 统计相关 Providers ====================

/// 获取某个 Style 下某个任务的完成次数
/// [styleId]: Style ID
/// [taskId]: Task ID
@riverpod
int taskCompletionCount(
  TaskCompletionCountRef ref,
  String styleId,
  String taskId,
) {
  final records = ref.watch(recordsByStyleIdProvider(styleId));
  
  int count = 0;
  for (final record in records) {
    if (record.taskCompletion[taskId] == true) {
      count++;
    }
  }
  return count;
}

/// 获取某个 Style 下所有任务的完成次数映射
/// 返回 Map `taskId` -> `completionCount`
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

/// 当前的连续打卡记录 (传入 styleId)
/// 如果今天有记录，则包含今天
/// 如果今天没有记录，则计算截至昨天的连续天数
/// 如果今天和昨天都没有记录，则返回 0
@riverpod
int currentStreak(CurrentStreakRef ref, String styleId) {
  final currentRecords = ref.watch(recordsByStyleIdProvider(styleId));
  if (currentRecords.isEmpty) return 0;

  // 转为日期对象排序
  final currentDates = currentRecords
      .map((r) => DateTime(r.date.year, r.date.month, r.date.day))
      .toList();
  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);
  final yesterdayDate = todayDate.subtract(const Duration(days: 1));
  
  // 今/昨有无打卡记录
  final hasTodayRecord = currentDates.any((d) => isSameDay(d, todayDate));
  final hasYesterdayRecord = currentDates.any((d) => isSameDay(d, yesterdayDate));

  if (!hasTodayRecord && !hasYesterdayRecord) return 0;
  
  int streak = 0;
  DateTime currentDate = hasTodayRecord ? todayDate : yesterdayDate;
  while (currentDates.any((d) => isSameDay(d, currentDate))) {
    streak++;
    currentDate = currentDate.subtract(const Duration(days: 1));
  }
  return streak;
}

// ==================== Style 派生数据 Providers ====================

/// 根据 Style 获取该 Style 的日期范围
@riverpod
DateTimeRange? styleDateRange(StyleDateRangeRef ref, {required Style? style}) {
  if (style == null) return null;
  
  final records = ref.watch(recordsByStyleIdProvider(style.id));
  if (records.isEmpty) {
    return DateTimeRange(
      start: getTodayDate(),
      end: getTodayDate(),
    );
  }
  
  // 相关记录已按日期倒序，最早日期=最后一条记录，最晚日期=第一条记录
  final earliestDate = DateTime(
    records.last.date.year,
    records.last.date.month,
    records.last.date.day,
  );
  final today = DateTime.now();
  final latestDate = DateTime(today.year, today.month, today.day);
  
  return DateTimeRange(start: earliestDate, end: latestDate);
}
