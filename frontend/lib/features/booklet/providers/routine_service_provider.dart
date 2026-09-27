import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:hive/hive.dart';

import 'package:torrid/core/api/user_data_sync.dart';
import 'package:torrid/features/booklet/models/record.dart';
import 'package:torrid/features/booklet/models/style.dart';
import 'package:torrid/features/booklet/providers/data_source_provider.dart';
import 'package:torrid/features/booklet/providers/style_provider.dart';
import 'package:torrid/features/booklet/providers/record_provider.dart';
import 'package:torrid/features/booklet/utils/checkin_stats.dart';
import 'package:torrid/core/utils/util.dart';

part 'routine_service_provider.g.dart';

/// Routine 业务服务层：负责所有数据的增删改操作和业务逻辑。
///
/// 同步语义：本地删除写墓碑（`deleted_at`）而不是物理删除，下载时按
/// `updated_at` 逐行合并（详见 `core/api/user_data_sync.dart`）。
/// 墓碑行只对同步可见 —— Box 流已在 `data_source_provider.dart` 里过滤，
/// 本文件里所有"派生统计"的遍历也必须过滤墓碑。

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
  Future<void> putStyle({required Style style}) async {
    final existing = state.styleBox.get(style.id);
    final times = touchSyncTimes(existing?.createdAt ?? style.createdAt);
    await state.styleBox.put(
      style.id,
      style.copyWith(
        createdAt: times.createdAt,
        updatedAt: times.updatedAt,
        clearDeleted: true,
      ),
    );
  }

  /// 删除 Style 记录（写墓碑，不是物理删除）
  Future<void> deleteStyle(String styleId) async {
    final style = state.styleBox.get(styleId);
    if (style == null || style.isTombstone) return;
    final times = tombstoneSyncTimes(style.createdAt);
    await state.styleBox.put(
      styleId,
      style.copyWith(
        createdAt: times.createdAt,
        updatedAt: times.updatedAt,
        deletedAt: times.deletedAt,
      ),
    );
  }

  // Record 操作

  /// 更新 Record，并更新对应的 Style 统计信息
  /// 如果完成情况和留言都为空，则删除记录（视为未打卡）；删除同样写墓碑，
  /// 否则"取消打卡"无法同步到另一端。
  Future<void> putRecord({
    required String styleId,
    required Record record,
  }) async {
    final stored = state.recordBox.get(record.id);
    final shouldDelete =
        record.message.isEmpty &&
        record.taskCompletion.values.every((isCompleted) => !isCompleted);

    if (shouldDelete) {
      if (stored != null && !stored.isTombstone) {
        final times = tombstoneSyncTimes(stored.createdAt);
        await state.recordBox.put(
          stored.id,
          stored.copyWith(
            createdAt: times.createdAt,
            updatedAt: times.updatedAt,
            deletedAt: times.deletedAt,
          ),
        );
      }
    } else {
      final times = touchSyncTimes(stored?.createdAt ?? record.createdAt);
      final stamped = record.copyWith(
        createdAt: times.createdAt,
        updatedAt: times.updatedAt,
        clearDeleted: true,
      );
      // 服务端的业务键是 (style_id, date)：同一业务键只保留一行，
      // 否则"删掉再补签"会在本地/服务端留下两条同一天的记录。
      await _removeSameDaySiblings(stamped);
      await state.recordBox.put(stamped.id, stamped);
    }
    await _refreshStyleStats(styleId);
  }

  /// 删除 Record 记录（写墓碑，不是物理删除）
  Future<void> deleteRecord(String recordId, String styleId) async {
    final record = state.recordBox.get(recordId);
    if (record != null && !record.isTombstone) {
      final times = tombstoneSyncTimes(record.createdAt);
      await state.recordBox.put(
        recordId,
        record.copyWith(
          createdAt: times.createdAt,
          updatedAt: times.updatedAt,
          deletedAt: times.deletedAt,
        ),
      );
    }
    await _refreshStyleStats(styleId);
  }

  /// 清掉与 [record] 同一 (style_id, date) 的其它本地行。
  ///
  /// 只可能出现在"删除后重新补签"（新草稿生成了新 id）这类场景，
  /// 被清掉的行要么是墓碑、要么是更旧的版本，丢弃它们不会丢失最新数据。
  Future<void> _removeSameDaySiblings(Record record) async {
    final matchKey = record.syncMatchKey;
    final siblings = state.recordBox.values
        .where((item) => item.id != record.id && item.syncMatchKey == matchKey)
        .map((item) => item.id)
        .toList();
    if (siblings.isNotEmpty) {
      await state.recordBox.deleteAll(siblings);
    }
  }

  // 批量操作

  /// 新建样式前，删除日期为今天的 Record 和 Style 记录（写墓碑）
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
      await deleteStyle(style.id);
    }
    for (final record in todayRecords) {
      await deleteRecord(record.id, record.styleId);
    }
  }

  /// 刷新所有 Style 的统计信息
  Future<void> refreshAllStats() async {
    final allStyles = ref.read(allStylesProvider);
    for (final style in allStyles) {
      await _refreshStyleStats(style.id);
    }
  }

  // 统计信息刷新

  /// 刷新单个 Style 的统计信息
  ///
  /// 派生重算：`copyWith` 保留同步时间戳，不让本地重算抢掉另一端的编辑。
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

  // 数据同步

  /// 数据同步：按 `updated_at` 逐行合并（含墓碑）
  ///
  /// 先完整解析校验、再计算合并计划、最后一次性写库，避免"已清空但解析失败"
  /// 造成本地数据丢失。服务端没有下发的本地行保持不动。
  /// 图片下载由 TransferController 统一处理（带进度），此处仅导入数据。
  Future<({int applied, int skipped})> syncData(dynamic json) async {
    if (json is! Map) {
      throw const FormatException('同步数据格式错误：应为 JSON 对象');
    }
    final data = Map<String, dynamic>.from(json);

    // 1) 完整解析校验（此时尚未改动任何本地数据）
    final styles = parseSyncRows<Style>(
      data['styles'],
      Style.fromJson,
      field: 'styles',
    );
    final records = parseSyncRows<Record>(
      data['records'],
      Record.fromJson,
      field: 'records',
    );

    // 2) 计算合并计划（纯函数）
    final stylePlan = planSyncMerge<Style>(
      local: state.styleBox.values,
      incoming: styles,
    );
    final recordPlan = planSyncMerge<Record>(
      local: state.recordBox.values,
      incoming: records,
    );

    // 3) 落地：每个 Box 一次批量写入
    if (stylePlan.upserts.isNotEmpty) {
      await state.styleBox.putAll(stylePlan.upserts);
    }
    if (stylePlan.removals.isNotEmpty) {
      await state.styleBox.deleteAll(stylePlan.removals);
    }
    if (recordPlan.upserts.isNotEmpty) {
      await state.recordBox.putAll(recordPlan.upserts);
    }
    if (recordPlan.removals.isNotEmpty) {
      await state.recordBox.deleteAll(recordPlan.removals);
    }

    return (
      applied: stylePlan.applied + recordPlan.applied,
      skipped: stylePlan.skipped + recordPlan.skipped,
    );
  }

  /// 备份数据，打包 JSON（**包含墓碑行**）
  ///
  /// 服务端逐行合并、载荷里缺席的行保持不动，因此必须把墓碑一并上报，
  /// "在另一端删除"才会生效。
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

    return packUserData({"styles": styles, "records": records});
  }

  /// 获取所有图片路径（墓碑样式的图片不再需要备份）
  List<String> getImgsPath() {
    List<String> urls = [];
    for (var style in liveSyncRows(state.styleBox.values)) {
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
