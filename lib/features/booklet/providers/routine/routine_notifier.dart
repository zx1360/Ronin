import 'dart:math';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:hive/hive.dart';
import 'package:torrid/services/io/io_service.dart';
import 'package:torrid/features/booklet/models/record.dart';
import 'package:torrid/features/booklet/models/style.dart';

import 'package:torrid/features/booklet/providers/routine/box_provider.dart';
import 'package:torrid/features/booklet/providers/routine/state_provider.dart';

import 'package:torrid/shared/utils/util.dart';

part 'routine_notifier.g.dart';

// --------------业务相关的数据操作
class Cashier {
  final Box<Style> styleBox;
  final Box<Record> recordBox;

  Cashier({required this.styleBox, required this.recordBox});
}

// 核心业务操作, 管理所有的数据修改.
@riverpod
class Server extends _$Server {
  @override
  Cashier build() {
    return Cashier(
      styleBox: ref.read(styleBoxProvider),
      recordBox: ref.read(recordBoxProvider),
    );
  }

  // 写入新Style记录
  Future<void> putStyle({required Style style}) async {
    final styleBox = state.styleBox;
    await styleBox.put(style.id, style);
  }

  // 更新Record, 并更新对应的style信息.
  Future<void> putRecord({
    required String styleId,
    required Record record,
  }) async {
    final recordBox = state.recordBox;
    await recordBox.put(record.id, record);
    await refreshOne(styleId);
  }

  // 新建样式前, 删除<日期为今天>的record记录和style记录
  Future<void> clearBeforeNewStyle() async {
    final allStyles = ref.read(stylesProvider);
    final allRecords = ref.read(recordsProvider);

    final todayStyles = allStyles
        .where((s) => isSameDay(s.startDate, DateTime.now()))
        .toList();
    final todayRecords = allRecords
        .where((r) => isSameDay(r.date, DateTime.now()))
        .toList();
    for (final style in todayStyles) {
      await state.styleBox.delete(style.id);
    }
    for (final record in todayRecords) {
      await state.recordBox.delete(record.id);
      await refreshOne(record.styleId);
    }
  }

  // 刷新Style的信息.
  Future<void> refreshAll() async {
    final allStyles = ref.read(stylesProvider);
    for (final style in allStyles) {
      await refreshOne(style.id);
    }
  }

  Future<void> refreshOne(String styleId) async {
    final styleBox = state.styleBox;
    final style = ref.read(styleWithIdProvider(styleId));
    if (style == null) return;

    final relatedRecords = ref.read(recordsWithStyleidProvider(styleId));
    // 计算各统计值.
    final validCheckIn = relatedRecords.length;
    final fullyDoneCount = _calculateFullyDone(relatedRecords);
    final longestStreak = _calculateLongestStreak(relatedRecords);
    final longestFullyStreak = _calculateLongestFullyStreak(relatedRecords);

    final updatedStyle = style.copyWith(
      validCheckIn: validCheckIn,
      fullyDone: fullyDoneCount,
      longestStreak: longestStreak,
      longestFullyStreak: longestFullyStreak,
    );

    await styleBox.put(style.id, updatedStyle);
  }

  // ----用以style更新信息计算的方法.
  int _getLongestConsecutiveDays(List<DateTime> sortedDates) {
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

  int _calculateFullyDone(List<Record> records) {
    return records.where((record) {
      return record.taskCompletion.values.every((flag) => flag);
    }).length;
  }

  int _calculateLongestStreak(List<Record> records) {
    final sortedDates =
        records
            .map((r) => DateTime(r.date.year, r.date.month, r.date.day))
            .toList()
          ..sort();
    return _getLongestConsecutiveDays(sortedDates);
  }

  int _calculateLongestFullyStreak(List<Record> records) {
    final fullyDoneDates =
        records
            .where((r) => r.taskCompletion.values.every((v) => v))
            .map((r) => DateTime(r.date.year, r.date.month, r.date.day))
            .toList()
          ..sort();
    return _getLongestConsecutiveDays(fullyDoneDates);
  }

  // ----数据同步, 替换为外部数据.
  Future<void> syncData(dynamic json) async {
    await state.styleBox.clear();
    await state.recordBox.clear();

    // 存储json数据到Hive.
    List jsonStyles = json['styles'];
    List jsonRecords = json['records'];
    for (dynamic style in jsonStyles) {
      Style style_ = Style.fromJson(style);
      await state.styleBox.put(style_.id, style_);
    }
    for (dynamic record in jsonRecords) {
      Record record_ = Record.fromJson(record);
      await state.recordBox.put(record_.id, record_);
    }
    // 将其中的task图片文件同时保存到本地.
    final List<String> urls = [];
    for (var style in state.styleBox.values) {
      style.tasks.where((task) => task.image.isNotEmpty).forEach((task) {
        urls.add(task.image);
      });
    }
    if (urls.isNotEmpty) {
      await IoService.saveFromRelativeUrls(urls, "img_storage/booklet");
    }
  }
}
