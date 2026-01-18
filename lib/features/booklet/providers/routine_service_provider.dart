import 'dart:convert';
import 'dart:math';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:hive/hive.dart';

import 'package:torrid/providers/network_service/network_provider.dart';
import 'package:torrid/features/booklet/models/record.dart';
import 'package:torrid/features/booklet/models/style.dart';
import 'package:torrid/features/booklet/providers/data_source_provider.dart';
import 'package:torrid/features/booklet/providers/style_provider.dart';
import 'package:torrid/features/booklet/providers/record_provider.dart';
import 'package:torrid/core/utils/util.dart';

part 'routine_service_provider.g.dart';

/// ============================================================================
/// Routine 业务服务层
/// 负责所有数据的增删改操作和业务逻辑
/// ============================================================================

/// 数据容器 - 封装 Style 和 Record 的 Hive Box
class RoutineDataContainer {
  final Box<Style> styleBox;
  final Box<Record> recordBox;

  RoutineDataContainer({
    required this.styleBox,
    required this.recordBox,
  });
}

/// 核心业务操作，管理所有的数据修改
@riverpod
class RoutineService extends _$RoutineService {
  @override
  RoutineDataContainer build() {
    return RoutineDataContainer(
      styleBox: ref.read(styleBoxProvider),
      recordBox: ref.read(recordBoxProvider),
    );
  }

  // ==================== Style 操作 ====================

  /// 写入新 Style 记录
  Future<void> putStyle({required Style style}) async {
    await state.styleBox.put(style.id, style);
  }

  /// 删除 Style 记录
  Future<void> deleteStyle(String styleId) async {
    await state.styleBox.delete(styleId);
  }

  // ==================== Record 操作 ====================

  /// 更新 Record，并更新对应的 Style 统计信息
  /// 如果完成情况和留言都为空，则删除记录（视为未打卡）
  Future<void> putRecord({
    required String styleId,
    required Record record,
  }) async {
    final shouldDelete = record.message.isEmpty &&
        record.taskCompletion.values.every((isCompleted) => !isCompleted);

    if (shouldDelete) {
      await state.recordBox.delete(record.id);
    } else {
      await state.recordBox.put(record.id, record);
    }
    await _refreshStyleStats(styleId);
  }

  /// 删除 Record 记录
  Future<void> deleteRecord(String recordId, String styleId) async {
    await state.recordBox.delete(recordId);
    await _refreshStyleStats(styleId);
  }

  // ==================== 批量操作 ====================

  /// 新建样式前，删除日期为今天的 Record 和 Style 记录
  Future<void> clearBeforeNewStyle() async {
    final allStyles = ref.read(allStylesProvider);
    final allRecords = ref.read(allRecordsProvider);

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
    }
  }

  /// 刷新所有 Style 的统计信息
  Future<void> refreshAllStats() async {
    final allStyles = ref.read(allStylesProvider);
    for (final style in allStyles) {
      await _refreshStyleStats(style.id);
    }
  }

  // ==================== 统计计算（私有方法） ====================

  /// 刷新单个 Style 的统计信息
  Future<void> _refreshStyleStats(String styleId) async {
    final style = ref.read(styleByIdProvider(styleId));
    if (style == null) return;

    final relatedRecords = ref.read(recordsByStyleIdProvider(styleId));
    
    // 计算各统计值
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

    await state.styleBox.put(style.id, updatedStyle);
  }

  /// 计算完全完成的天数
  int _calculateFullyDone(List<Record> records) {
    return records.where((record) {
      return record.taskCompletion.values.every((flag) => flag);
    }).length;
  }

  /// 计算最长连续打卡天数
  int _calculateLongestStreak(List<Record> records) {
    final sortedDates = records
        .map((r) => DateTime(r.date.year, r.date.month, r.date.day))
        .toList()
      ..sort();
    return _getLongestConsecutiveDays(sortedDates);
  }

  /// 计算最长连续全完成天数
  int _calculateLongestFullyStreak(List<Record> records) {
    final fullyDoneDates = records
        .where((r) => r.taskCompletion.values.every((v) => v))
        .map((r) => DateTime(r.date.year, r.date.month, r.date.day))
        .toList()
      ..sort();
    return _getLongestConsecutiveDays(fullyDoneDates);
  }

  /// 获取最长连续天数
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

  // ==================== 数据同步 ====================

  /// 数据同步，替换为外部数据
  Future<void> syncData(dynamic json) async {
    await state.styleBox.clear();
    await state.recordBox.clear();

    // 存储 JSON 数据到 Hive
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
    
    // 将其中的 task 图片文件同时保存到本地
    final List<String> urls = [];
    for (var style in state.styleBox.values) {
      style.tasks.where((task) => task.image.isNotEmpty).forEach((task) {
        urls.add(task.image);
      });
    }
    if (urls.isNotEmpty) {
      await ref.read(
        saveFromRelativeUrlsProvider(urls: urls, relativeDir: "img_storage/booklet").future,
      );
    }
  }

  /// 备份数据，打包 JSON
  Map<String, dynamic> packUp() {
    final styles = (state.styleBox.values.toList()
          ..sort((a, b) => b.startDate.compareTo(a.startDate)))
        .map((item) => item.toJson())
        .toList();

    final records = (state.recordBox.values.toList()
          ..sort((a, b) => b.date.compareTo(a.date)))
        .map((item) => item.toJson())
        .toList();

    return {
      "jsonData": jsonEncode({"styles": styles, "records": records}),
    };
  }

  /// 获取所有图片路径
  List<String> getImgsPath() {
    List<String> urls = [];
    for (var style in state.styleBox.values) {
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
}
