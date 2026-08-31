import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:hive/hive.dart';

import 'package:torrid/features/booklet/models/record.dart';
import 'package:torrid/features/booklet/models/style.dart';
import 'package:torrid/features/booklet/providers/data_source_provider.dart';
import 'package:torrid/features/booklet/providers/style_provider.dart';
import 'package:torrid/features/booklet/providers/record_provider.dart';
import 'package:torrid/features/booklet/utils/checkin_stats.dart';
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

  RoutineDataContainer({required this.styleBox, required this.recordBox});
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
    final shouldDelete =
        record.message.isEmpty &&
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

  // ==================== 统计信息刷新 ====================

  /// 刷新单个 Style 的统计信息
  Future<void> _refreshStyleStats(String styleId) async {
    final style = ref.read(styleByIdProvider(styleId));
    if (style == null) return;

    final relatedRecords = ref.read(recordsByStyleIdProvider(styleId));

    // 计算各统计值（复用模块通用统计函数）
    final validCheckIn = relatedRecords.length;
    final fullyDoneCount = countFullyDone(relatedRecords);
    final longestStreakDays = longestStreak(relatedRecords);
    final longestFullyStreakDays = longestFullyStreak(relatedRecords);

    final updatedStyle = style.copyWith(
      validCheckIn: validCheckIn,
      fullyDone: fullyDoneCount,
      longestStreak: longestStreakDays,
      longestFullyStreak: longestFullyStreakDays,
    );

    await state.styleBox.put(style.id, updatedStyle);
  }

  // ==================== 数据同步 ====================

  /// 数据同步，替换为外部数据
  /// 注意：图片下载由 TransferController._downloadImages 统一处理（带进度），此处仅导入数据
  Future<void> syncData(dynamic json) async {
    await state.styleBox.clear();
    await state.recordBox.clear();

    // 存储 JSON 数据到 Hive
    final jsonStyles = json['styles'] as List;
    final jsonRecords = json['records'] as List;

    for (final styleJson in jsonStyles) {
      final parsedStyle = Style.fromJson(styleJson as Map<String, dynamic>);
      await state.styleBox.put(parsedStyle.id, parsedStyle);
    }
    for (final recordJson in jsonRecords) {
      final parsedRecord = Record.fromJson(recordJson as Map<String, dynamic>);
      await state.recordBox.put(parsedRecord.id, parsedRecord);
    }

    // 修复历史漂移：旧版本"本地时间无时区字符串被服务端按 UTC 解析"会使
    // style.start_date 每次备份/同步往返累积偏移
    // await _healDriftedStartDates();
  }

  /// 校正历史遗留的 start_date 漂移（仅当 start_date 晚于该 style 的最早记录日期时）。
  // Future<void> _healDriftedStartDates() async {
  //   for (final style in state.styleBox.values.toList()) {
  //     final styleRecords = state.recordBox.values
  //         .where((r) => r.styleId == style.id)
  //         .toList();
  //     if (styleRecords.isEmpty) continue;

  //     final earliestDate = styleRecords
  //         .map((r) => dateOnly(r.date))
  //         .reduce((a, b) => a.isBefore(b) ? a : b);

  //     if (dateOnly(style.startDate).isAfter(earliestDate)) {
  //       await state.styleBox.put(
  //         style.id,
  //         style.copyWith(startDate: earliestDate),
  //       );
  //     }
  //   }
  // }

  /// 备份数据，打包 JSON
  Map<String, dynamic> packUp() {
    final styles =
        (state.styleBox.values.toList()
              ..sort((a, b) => b.startDate.compareTo(a.startDate)))
            .map((item) => item.toJson())
            .toList();

    final records =
        (state.recordBox.values.toList()
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
