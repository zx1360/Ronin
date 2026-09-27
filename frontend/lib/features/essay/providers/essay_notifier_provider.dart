/// Essay 模块的核心业务逻辑服务
///
/// 提供随笔的增删改查、标签管理、数据同步等功能。
///
/// 同步语义：本地删除写墓碑（`deleted_at`）而不是物理删除，下载时按
/// `updated_at` 逐行合并（详见 `core/api/user_data_sync.dart`）。
/// 墓碑行只对同步可见 —— Box 流已在 `box_provider.dart` 里过滤，
/// 本文件里所有"派生统计"的遍历也必须用 [liveSyncRows] 过滤。
library;

import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/core/api/user_data_sync.dart';
import 'package:torrid/features/essay/models/essay.dart';
import 'package:torrid/features/essay/models/label.dart';
import 'package:torrid/features/essay/models/year_summary.dart';
import 'package:torrid/features/essay/providers/box_provider.dart';
import 'package:torrid/features/essay/providers/setting_provider.dart';
import 'package:torrid/core/models/message.dart';

part 'essay_notifier_provider.g.dart';

/// Essay 模块的数据仓库
///
/// 封装对 [YearSummary]、[Essay]、[Label] 三个 Box 的访问。
class EssayRepository {
  final Box<YearSummary> summaryBox;
  final Box<Essay> essayBox;
  final Box<Label> labelBox;

  const EssayRepository({
    required this.summaryBox,
    required this.essayBox,
    required this.labelBox,
  });
}

/// Essay 模块的核心服务
///
/// 提供以下功能：
/// - 随笔 CRUD 操作
/// - 标签管理
/// - 年度/月度统计更新
/// - 数据同步与备份（逐行合并 + 墓碑）
@riverpod
class EssayService extends _$EssayService {
  @override
  EssayRepository build() {
    return EssayRepository(
      summaryBox: ref.read(summaryBoxProvider),
      essayBox: ref.read(essayBoxProvider),
      labelBox: ref.read(labelBoxProvider),
    );
  }

  /// 按当前随笔数据重算全部年度/月度统计，并补齐缺失的年度
  ///
  /// 墓碑随笔不参与统计；没有随笔的年度不物理删除，而是写墓碑，
  /// 这样"这一年没有随笔了"也能同步到另一端。
  Future<void> refreshYear() async {
    final allEssays = liveSyncRows(state.essayBox.values).toList();
    final years = allEssays.map((essay) => essay.date.year.toString()).toSet();

    final now = DateTime.now();
    final upserts = <String, YearSummary>{};
    for (final year in years) {
      final existing = state.summaryBox.get(year);
      final fresh = YearSummary.fromEssays(year, allEssays);
      if (existing == null) {
        final times = touchSyncTimes(null);
        upserts[year] = fresh.copyWith(
          createdAt: times.createdAt,
          updatedAt: times.updatedAt,
        );
      } else if (existing.isTombstone) {
        // 有活随笔却挂着墓碑：复活它，并且必须推进 updated_at 才能盖过墓碑
        upserts[year] = fresh.copyWith(
          createdAt: existing.createdAt,
          updatedAt: now,
          clearDeleted: true,
        );
      } else {
        // 纯派生重算：保留既有时间戳，不抢其它设备的真实编辑
        upserts[year] = fresh.copyWith(
          createdAt: existing.createdAt,
          updatedAt: existing.updatedAt,
        );
      }
    }

    final tombstones = <String, YearSummary>{};
    for (final key in state.summaryBox.keys) {
      if (years.contains(key)) continue;
      final existing = state.summaryBox.get(key);
      if (existing == null || existing.isTombstone) continue;
      final times = tombstoneSyncTimes(existing.createdAt);
      tombstones[key as String] = existing.copyWith(
        createdAt: times.createdAt,
        updatedAt: times.updatedAt,
        deletedAt: times.deletedAt,
      );
    }

    if (upserts.isNotEmpty) await state.summaryBox.putAll(upserts);
    if (tombstones.isNotEmpty) await state.summaryBox.putAll(tombstones);
  }

  /// 按当前随笔数据重算所有标签的随笔计数
  ///
  /// 计数以随笔实际引用为准，因此计数为 0 的标签同样会被写回（否则会与
  /// [deleteZeroLabels] 形成"计数永不归零 → 标签被误删"的竞态）。
  /// 墓碑随笔/标签都不参与，且重算不刷新 `updated_at`（派生数据不该抢编辑）。
  Future<void> refreshLabel() async {
    final counts = <String, int>{};
    for (final essay in liveSyncRows(state.essayBox.values)) {
      for (final labelId in essay.labels) {
        counts[labelId] = (counts[labelId] ?? 0) + 1;
      }
    }

    final corrected = <String, Label>{};
    for (final label in liveSyncRows(state.labelBox.values)) {
      final count = counts[label.id] ?? 0;
      if (label.essayCount != count) {
        corrected[label.id] = label.copyWith(essayCount: count);
      }
    }
    if (corrected.isNotEmpty) {
      await state.labelBox.putAll(corrected);
    }
  }

  /// 写入新随笔
  ///
  /// 同时更新相关标签计数和年度/月度统计信息。
  Future<void> writeEssay({required Essay essay}) async {
    final times = touchSyncTimes(essay.createdAt);
    final stamped = essay.copyWith(
      createdAt: times.createdAt,
      updatedAt: times.updatedAt,
      clearDeleted: true,
    );
    await state.essayBox.put(stamped.id, stamped);

    // 更新标签计数（标签不存在或已删除时跳过，避免脏数据崩溃）
    for (final labelId in stamped.labels) {
      final label = state.labelBox.get(labelId);
      if (label == null || label.isTombstone) continue;
      await state.labelBox.put(
        labelId,
        label.copyWith(essayCount: label.essayCount + 1),
      );
    }

    // 更新年度统计
    await _updateYearSummaryOnAdd(stamped);
  }

  /// 删除随笔（写墓碑，不是物理删除）
  ///
  /// 同时更新相关标签计数和年度/月度统计信息。
  Future<void> deleteEssay(Essay essay) async {
    final target = state.essayBox.get(essay.id) ?? essay;
    if (!target.isTombstone) {
      final times = tombstoneSyncTimes(target.createdAt);
      await state.essayBox.put(
        target.id,
        target.copyWith(
          createdAt: times.createdAt,
          updatedAt: times.updatedAt,
          deletedAt: times.deletedAt,
        ),
      );
    }

    // 更新标签计数（标签不存在或已删除时跳过）
    for (final labelId in target.labels) {
      final label = state.labelBox.get(labelId);
      if (label == null || label.isTombstone) continue;
      await state.labelBox.put(
        labelId,
        label.copyWith(essayCount: label.essayCount - 1),
      );
    }

    // 更新年度统计（年度汇总缺失时跳过）
    final yearSummary = state.summaryBox.get(target.date.year.toString());
    if (yearSummary == null) return;
    await state.summaryBox.put(
      yearSummary.year,
      yearSummary.edit(essay: target, isAppend: false),
    );
  }

  /// 更新年度统计（添加随笔时）
  Future<void> _updateYearSummaryOnAdd(Essay essay) async {
    final yearKey = essay.date.year.toString();
    final yearSummary = state.summaryBox.get(yearKey);

    if (yearSummary == null) {
      // 创建新年度统计（新行才需要落同步时间戳）
      final times = touchSyncTimes(null);
      final newYearSummary = YearSummary(
        year: yearKey,
        essayCount: 1,
        wordCount: essay.wordCount,
        monthSummaries: [
          MonthSummary(
            month: essay.date.month.toString(),
            essayCount: 1,
            wordCount: essay.wordCount,
          ),
        ],
        createdAt: times.createdAt,
        updatedAt: times.updatedAt,
      );
      await state.summaryBox.put(yearKey, newYearSummary);
    } else {
      // 更新现有年度统计（派生重算保留同步元数据）
      await state.summaryBox.put(
        yearKey,
        yearSummary.edit(essay: essay, isAppend: true),
      );
    }
  }

  /// 对某篇随笔的标签进行切换（添加/移除）
  ///
  /// 确保每篇随笔至少有一个标签。
  Future<void> retag(String essayId, String labelId) async {
    final originalEssay = state.essayBox.get(essayId);
    final originalLabel = state.labelBox.get(labelId);
    if (originalEssay == null ||
        originalEssay.isTombstone ||
        originalLabel == null ||
        originalLabel.isTombstone) {
      return;
    }

    final List<String> updatedLabels;
    final int labelCountDelta;
    if (originalEssay.labels.contains(labelId)) {
      // 移除标签（确保至少保留一个）
      if (originalEssay.labels.length <= 1) return;
      updatedLabels = List<String>.from(originalEssay.labels)..remove(labelId);
      labelCountDelta = -1;
    } else {
      // 添加标签
      updatedLabels = List<String>.from(originalEssay.labels)..add(labelId);
      labelCountDelta = 1;
    }

    final times = touchSyncTimes(originalEssay.createdAt);
    final updatedEssay = originalEssay.copyWith(
      labels: updatedLabels,
      createdAt: times.createdAt,
      updatedAt: times.updatedAt,
    );
    await state.essayBox.put(updatedEssay.id, updatedEssay);
    await state.labelBox.put(
      labelId,
      originalLabel.copyWith(
        essayCount: originalLabel.essayCount + labelCountDelta,
      ),
    );

    // 更新当前显示的随笔
    ref.read(contentServerProvider.notifier).switchEssay(updatedEssay);
    await refreshLabel();
  }

  /// 对某篇随笔追加留言
  Future<void> appendMessage(String essayId, Message message) async {
    final originalEssay = state.essayBox.get(essayId);
    if (originalEssay == null || originalEssay.isTombstone) return;

    final updatedMessages = List<Message>.from(originalEssay.messages)
      ..add(message);
    final times = touchSyncTimes(originalEssay.createdAt);
    final essay = originalEssay.copyWith(
      messages: updatedMessages,
      createdAt: times.createdAt,
      updatedAt: times.updatedAt,
    );
    await state.essayBox.put(essay.id, essay);

    // 更新当前显示的随笔
    ref.read(contentServerProvider.notifier).switchEssay(essay);
  }

  /// 新增标签
  Future<void> addLabel(String name) async {
    final label = Label.newOne(name);
    await state.labelBox.put(label.id, label);
  }

  /// 删除没有任何随笔引用的标签（写墓碑）
  ///
  /// 以随笔实际引用为准而非标签上的计数，避免误删仍被引用的标签。
  Future<void> deleteZeroLabels() async {
    final referenced = <String>{};
    for (final essay in liveSyncRows(state.essayBox.values)) {
      referenced.addAll(essay.labels);
    }

    final tombstones = <String, Label>{};
    for (final label in liveSyncRows(state.labelBox.values)) {
      if (referenced.contains(label.id)) continue;
      final times = tombstoneSyncTimes(label.createdAt);
      tombstones[label.id] = label.copyWith(
        createdAt: times.createdAt,
        updatedAt: times.updatedAt,
        deletedAt: times.deletedAt,
      );
    }
    if (tombstones.isNotEmpty) {
      await state.labelBox.putAll(tombstones);
    }
  }

  /// 从服务器同步数据（按 `updated_at` 逐行合并，含墓碑）
  ///
  /// 先把三张表的全部数据解析校验完，再计算合并计划，最后才写库：任何一条数据非法
  /// 都直接抛出，不会留下"已清空但未导入"的空库，也不会写坏已有数据。
  /// 服务端没有下发的本地行**保持不动**（缺席 ≠ 删除，删除只以墓碑表达）。
  /// 图片下载由 TransferController 统一处理（带进度），此处仅导入数据。
  Future<({int applied, int skipped})> syncData(dynamic json) async {
    if (json is! Map) {
      throw const FormatException('同步数据格式错误：应为 JSON 对象');
    }
    final data = Map<String, dynamic>.from(json);

    // 1) 完整解析校验（此时尚未改动任何本地数据）
    final summaries = parseSyncRows<YearSummary>(
      data['year_summaries'],
      YearSummary.fromJson,
      field: 'year_summaries',
    );
    final labels = parseSyncRows<Label>(
      data['labels'],
      Label.fromJson,
      field: 'labels',
    );
    final essays = parseSyncRows<Essay>(
      data['essays'],
      Essay.fromJson,
      field: 'essays',
    );

    // 2) 计算合并计划（纯函数）
    final summaryPlan = planSyncMerge<YearSummary>(
      local: state.summaryBox.values,
      incoming: summaries,
    );
    final labelPlan = planSyncMerge<Label>(
      local: state.labelBox.values,
      incoming: labels,
    );
    final essayPlan = planSyncMerge<Essay>(
      local: state.essayBox.values,
      incoming: essays,
    );

    // 3) 落地：每个 Box 一次批量写入
    if (summaryPlan.upserts.isNotEmpty) {
      await state.summaryBox.putAll(summaryPlan.upserts);
    }
    if (summaryPlan.removals.isNotEmpty) {
      await state.summaryBox.deleteAll(summaryPlan.removals);
    }
    if (labelPlan.upserts.isNotEmpty) {
      await state.labelBox.putAll(labelPlan.upserts);
    }
    if (labelPlan.removals.isNotEmpty) {
      await state.labelBox.deleteAll(labelPlan.removals);
    }
    if (essayPlan.upserts.isNotEmpty) {
      await state.essayBox.putAll(essayPlan.upserts);
    }
    if (essayPlan.removals.isNotEmpty) {
      await state.essayBox.deleteAll(essayPlan.removals);
    }

    return (
      applied:
          summaryPlan.applied + labelPlan.applied + essayPlan.applied,
      skipped:
          summaryPlan.skipped + labelPlan.skipped + essayPlan.skipped,
    );
  }

  /// 打包本地数据用于备份（**包含墓碑行**）
  ///
  /// 服务端逐行合并、载荷里缺席的行保持不动，因此必须把墓碑一并上报，
  /// "在另一端删除"才会生效。
  Map<String, dynamic> packUp() {
    final yearSummaries =
        (state.summaryBox.values.toList()
              ..sort((a, b) => b.year.compareTo(a.year)))
            .map((item) => item.toJson())
            .toList();

    final labels =
        (state.labelBox.values.toList()
              ..sort((a, b) => b.essayCount.compareTo(a.essayCount)))
            .map((item) => item.toJson())
            .toList();

    final essays =
        (state.essayBox.values.toList()
              ..sort((a, b) => b.date.compareTo(a.date)))
            .map((item) => item.toJson())
            .toList();

    return packUserData({
      "year_summaries": yearSummaries,
      "labels": labels,
      "essays": essays,
    });
  }

  /// 获取所有随笔图片的相对路径（墓碑随笔的图片不再需要备份）
  List<String> getImgsPath() {
    final urls = <String>[];
    for (final essay in liveSyncRows(state.essayBox.values)) {
      for (final img in essay.imgs) {
        final relativePath = img.startsWith("/")
            ? img.replaceFirst("/", "")
            : img;
        urls.add(relativePath);
      }
    }
    return urls;
  }
}
