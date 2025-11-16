import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:torrid/features/booklet/providers/box_provider.dart';
import 'package:torrid/features/booklet/models/record.dart';
import 'package:torrid/features/booklet/models/style.dart';
import 'package:torrid/shared/utils/util.dart';

part 'status_provider.g.dart';

// 监听Hive数据变化, 对外提供'即拿即用'的响应式数据.
// StreamProvider实现对于box内容的实时性, 普通Provider对外暴露简单的同步数据.
// styles记录
@riverpod
List<Style> styles(StylesRef ref) {
  final asyncVal = ref.watch(styleStreamProvider);
  if (asyncVal.hasError) {
    throw asyncVal.error!;
  }
  return asyncVal.asData?.value ?? [];
}

// records记录.
@riverpod
List<Record> records(RecordsRef ref) {
  final asyncVal = ref.watch(recordStreamProvider);
  if (asyncVal.hasError) {
    throw asyncVal.error!;
  }
  return asyncVal.asData?.value ?? [];
}

// ------------获取对象记录
// 根据styleId获取style
@riverpod
Style? styleWithId(StyleWithIdRef ref, String styleId) {
  return ref.read(styleBoxProvider).get(styleId);
}

// 最近的style
@riverpod
Style? latestStyle(LatestStyleRef ref) {
  final allStyles = ref.watch(stylesProvider);
  if (allStyles.isEmpty) return null;
  return allStyles.reduce((a, b) => a.startDate.isAfter(b.startDate) ? a : b);
}

// 今天的record(最近的style), 无则返回null.
@riverpod
Record? todayRecord(TodayRecordRef ref) {
  final todayStyle = ref.watch(latestStyleProvider);
  if (todayStyle == null) return null;
  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);
  final allRecords = ref.watch(recordsProvider);

  final todayRecords = allRecords
      .where(
        (item) =>
            item.styleId == todayStyle.id &&
            isSameDay(item.date, todayDate),
      )
      .toList();

  return todayRecords.isNotEmpty ? todayRecords.first : null;
}

// 根据styleId返回关联的倒序的所有records
@riverpod
List<Record> recordsWithStyleid(RecordsWithStyleidRef ref, String styleId) {
  final allRecords = ref.watch(recordsProvider);
  return allRecords.where((item) => item.styleId == styleId).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
}

// ------------带有业务逻辑的数据 UI使用
// 当前的连续打卡记录 (传入styleId)
/// 如果今天有记录，则包含今天
/// 如果今天没有记录，则计算截至昨天的连续天数
/// 如果今天和昨天都没有记录，则返回0
@riverpod
int currentStreak(CurrentStreakRef ref, String styleId) {
  final currentRecords = ref.watch(recordsWithStyleidProvider(styleId));
  if (currentRecords.isEmpty) return 0;

  // 转为日期对象排序.
  final currentDates = currentRecords
      .map((r) => DateTime(r.date.year, r.date.month, r.date.day))
      .toList();
  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);
  final yesterdayDate = todayDate.subtract(const Duration(days: 1));
  // 今/昨有无打卡记录.
  final hasTodayRecord = currentRecords.any((r) => r.date == todayDate);
  final hasYesterdayRecord = currentRecords.any((r) => r.date == yesterdayDate);

  if (!hasTodayRecord && !hasYesterdayRecord) return 0;
  int streak = 0;
  DateTime currentDate = hasTodayRecord ? todayDate : yesterdayDate;
  while (currentDates.contains(currentDate)) {
    streak++;
    currentDate = currentDate.subtract(const Duration(days: 1));
  }
  return streak;
}

// ------------带有业务逻辑的数据 非UI使用
@riverpod
Map<String, dynamic> jsonData(JsonDataRef ref) {
  final sortedStyles = ref.watch(stylesProvider)
    ..sort((a, b) => b.startDate.compareTo(a.startDate))
    ..map((item) => item.toJson()).toList();
  final sortedRecords = ref.watch(recordsProvider)
    ..sort((a, b) => b.date.compareTo(a.date))
    ..map((item) => item.toJson()).toList();

  return {
    "jsonData": jsonEncode({"styles": sortedStyles, "records": sortedRecords}),
  };
}

@riverpod
List<String> imgPaths(ImgPathsRef ref) {
  final allStyles = ref.watch(stylesProvider);
  const List<String> urls = [];
  for (final style in allStyles) {
    style.tasks
        .where((task) => task.image.isNotEmpty && task.image != '')
        .forEach((task) {
          final relativePath = task.image.startsWith("/")
              ? task.image.replaceFirst("/", "")
              : task.image;
          urls.add(relativePath);
        });
  }
  return urls;
}
