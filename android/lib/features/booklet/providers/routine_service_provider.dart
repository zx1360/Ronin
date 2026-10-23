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

class RoutineDataContainer {
  final Box<Style> styleBox;
  final Box<Record> recordBox;

  RoutineDataContainer({required this.styleBox, required this.recordBox});
}

@riverpod
class RoutineService extends _$RoutineService {
  @override
  RoutineDataContainer build() {
    return RoutineDataContainer(
      styleBox: ref.read(styleBoxProvider),
      recordBox: ref.read(recordBoxProvider),
    );
  }

  /// 保存记录并重算计划统计；无留言、心情和完成项时撤销打卡。
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

  Future<void> createStyle({
    required Style style,
    required bool replaceToday,
  }) => userDataWrite(() async {
    if (style.tasks.isEmpty ||
        style.tasks.length > 5 ||
        style.tasks.any((task) => task.title.trim().isEmpty)) {
      throw const FormatException('样式需要 1–5 个非空任务');
    }
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
    if (!replaceToday &&
        (removedStyles.isNotEmpty || removedRecords.isNotEmpty)) {
      throw StateError('今天的样式或打卡已变化，请重新确认');
    }
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
    styles[style.id] = style.copyWith(updatedAt: nextUserDataTime());
    await replaceBoxes({
      userDataSyncBox: metadata,
      state.recordBox: records,
      state.styleBox: <String, Style>{
        for (final item in styles.values)
          item.id: _withStats(item, records.values),
      },
    });
  });

  Style _withStats(Style style, Iterable<Record> records) {
    final related = records.where((r) => r.styleId == style.id).toList();
    return style.copyWith(
      validCheckIn: related.length,
      fullyDone: countFullyDone(related),
      longestStreak: longestStreak(related),
      longestFullyStreak: longestFullyStreak(related),
    );
  }

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
