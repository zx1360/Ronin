import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:hive/hive.dart';
import 'package:torrid/core/services/storage/box_replace.dart';
import 'package:torrid/core/services/storage/user_data_sync.dart';

import 'package:torrid/features/booklet/models/record.dart';
import 'package:torrid/features/booklet/models/style.dart';
import 'package:torrid/features/booklet/providers/data_source_provider.dart';
import 'package:torrid/features/booklet/utils/checkin_stats.dart';
import 'package:torrid/core/utils/util.dart';

part 'routine_service_provider.g.dart';

/// Routine 业务服务层：负责所有数据的增删改操作和业务逻辑。

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

  // Style 操作

  /// 写入新 Style 记录
  Future<void> putStyle({required Style style}) => userDataWrite(() async {
    await state.styleBox.put(
      style.id,
      style.copyWith(
        updatedAt: nextUserDataTime(state.styleBox.get(style.id)?.updatedAt),
      ),
    );
  });

  // Record 操作

  /// 更新 Record，并更新对应的 Style 统计信息
  /// 如果完成情况和留言都为空，则删除记录（视为未打卡）
  Future<void> putRecord({required String styleId, required Record record}) =>
      userDataWrite(() async {
        final records = state.recordBox.toMap().cast<String, Record>();
        final previous = records[record.id]?.updatedAt;
        final shouldDelete =
            record.message.isEmpty &&
            record.mood == null &&
            record.taskCompletion.values.every((flag) => !flag);
        if (shouldDelete) {
          records.remove(record.id);
        } else {
          records[record.id] = record.copyWith(
            updatedAt: nextUserDataTime(previous),
          );
        }
        final styles = state.styleBox.toMap().cast<String, Style>();
        final style = styles[styleId];
        if (style != null) styles[styleId] = _withStats(style, records.values);
        await replaceBoxes({
          if (shouldDelete)
            userDataSyncBox: deletedUserData(
              'booklet',
              'records',
              record.id,
              previous,
            ),
          state.recordBox: records,
          state.styleBox: styles,
        });
      });

  Future<void> clearBeforeNewStyle() => userDataWrite(() async {
    final styles = state.styleBox.toMap().cast<String, Style>();
    final records = state.recordBox.toMap().cast<String, Record>();
    var metadata = userDataSyncBox.toMap().cast<String, String>();
    final removedStyles = styles.values
        .where((s) => isSameDay(s.startDate, DateTime.now()))
        .toList();
    final removedIds = removedStyles.map((s) => s.id).toSet();
    final removedRecords = records.values
        .where(
          (r) =>
              isSameDay(r.date, DateTime.now()) ||
              removedIds.contains(r.styleId),
        )
        .toList();
    for (final record in removedRecords) {
      records.remove(record.id);
      metadata = deletedUserData(
        'booklet',
        'records',
        record.id,
        record.updatedAt,
        metadata: metadata,
      );
    }
    for (final style in removedStyles) {
      styles.remove(style.id);
      final versions = [
        style.updatedAt,
        ...removedRecords
            .where((r) => r.styleId == style.id)
            .map((r) => r.updatedAt),
      ].whereType<DateTime>().toList()..sort();
      metadata = deletedUserData(
        'booklet',
        'styles',
        style.id,
        versions.lastOrNull,
        metadata: metadata,
      );
    }
    await replaceBoxes({
      userDataSyncBox: metadata,
      state.recordBox: records,
      state.styleBox: styles,
    });
  });

  /// 刷新所有 Style 的统计信息
  Future<void> refreshAllStats() => userDataWrite(() async {
    final allStyles = state.styleBox.values.toList();
    for (final style in allStyles) {
      await _refreshStyleStats(style.id);
    }
  });

  // 统计信息刷新

  Style _withStats(Style style, Iterable<Record> records) {
    final related = records.where((r) => r.styleId == style.id).toList();
    return style.copyWith(
      validCheckIn: related.length,
      fullyDone: countFullyDone(related),
      longestStreak: longestStreak(related),
      longestFullyStreak: longestFullyStreak(related),
    );
  }

  Future<void> _refreshStyleStats(String styleId) async {
    final style = state.styleBox.get(styleId);
    if (style != null) {
      await state.styleBox.put(
        style.id,
        _withStats(style, state.recordBox.values),
      );
    }
  }

  // 数据同步

  /// 逐行合并，图片由传输控制器处理。
  Future<void> syncData(dynamic incoming, {String? cursorKey}) =>
      userDataWrite(() async {
        final merged = mergeUserData(
          'booklet',
          snapshot(),
          Map<String, dynamic>.from(incoming as Map),
        );
        final json = merged.data;
        final styles = <String, Style>{};
        for (final raw in json['styles'] as List) {
          final style = Style.fromJson(raw as Map<String, dynamic>);
          styles[style.id] = style;
        }

        final records = <String, Record>{};
        for (final raw in json['records'] as List) {
          final record = Record.fromJson(raw as Map<String, dynamic>);
          records[record.id] = record;
        }

        final days = <String>{};
        for (final record in records.values) {
          final style = styles[record.styleId];
          if (style == null) {
            throw const FormatException('打卡记录引用了不存在的样式');
          }
          if (!days.add('${record.styleId}|${record.date}') ||
              record.taskCompletion.length != style.tasks.length ||
              style.tasks.any(
                (task) => !record.taskCompletion.containsKey(task.id),
              )) {
            throw const FormatException('打卡日期重复或任务与样式不一致');
          }
        }
        if (cursorKey != null) {
          merged.metadata[cursorKey] = incoming['cursor'].toString();
        }
        await replaceBoxes({
          userDataSyncBox: merged.metadata,
          state.styleBox: <String, Style>{
            for (final style in styles.values)
              style.id: _withStats(style, records.values),
          },
          state.recordBox: records,
        });
      });

  Map<String, dynamic> snapshot() => {
    'styles': state.styleBox.values.map((s) => s.toJson()).toList(),
    'records': state.recordBox.values.map((r) => r.toJson()).toList(),
  };

  Future<Map<String, dynamic>> packUp() => userDataWrite(() async {
    for (final style in state.styleBox.values.toList()) {
      if (style.updatedAt == null) {
        await state.styleBox.put(
          style.id,
          style.copyWith(updatedAt: nextUserDataTime()),
        );
      }
    }
    for (final record in state.recordBox.values.toList()) {
      if (record.updatedAt == null) {
        await state.recordBox.put(
          record.id,
          record.copyWith(updatedAt: nextUserDataTime()),
        );
      }
    }
    return {
      'jsonData': jsonEncode({
        ...snapshot(),
        'sync_version': 2,
        'tombstones': userDataTombstones('booklet'),
      }),
    };
  });
}
