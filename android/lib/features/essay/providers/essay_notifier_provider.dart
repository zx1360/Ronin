/// Essay 模块的核心业务逻辑服务
///
/// 提供随笔的增删改查、标签管理、数据同步等功能。
library;

import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
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
/// - 数据同步与备份
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
  Future<void> refreshYear() async {
    final allEssays = state.essayBox.values;
    final years = allEssays.map((essay) => essay.date.year.toString()).toSet();

    final updated = <String, YearSummary>{
      for (final year in years) year: YearSummary.fromEssays(year, allEssays),
    };
    final stale = state.summaryBox.keys
        .where((key) => !years.contains(key))
        .toList();

    if (updated.isNotEmpty) {
      await state.summaryBox.putAll(updated);
    }
    if (stale.isNotEmpty) {
      await state.summaryBox.deleteAll(stale);
    }
  }

  /// 按当前随笔数据重算所有标签的随笔计数
  ///
  /// 计数以随笔实际引用为准，因此计数为 0 的标签同样会被写回（否则会与
  /// [deleteZeroLabels] 形成"计数永不归零 → 标签被误删"的竞态）。
  Future<void> refreshLabel() async {
    final counts = <String, int>{};
    for (final essay in state.essayBox.values) {
      for (final labelId in essay.labels) {
        counts[labelId] = (counts[labelId] ?? 0) + 1;
      }
    }

    final corrected = <String, Label>{};
    for (final label in state.labelBox.values) {
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
    await state.essayBox.put(essay.id, essay);

    // 更新标签计数（标签不存在时跳过，避免脏数据崩溃）
    for (final labelId in essay.labels) {
      final label = state.labelBox.get(labelId);
      if (label == null) continue;
      await state.labelBox.put(
        labelId,
        label.copyWith(essayCount: label.essayCount + 1),
      );
    }

    // 更新年度统计
    await _updateYearSummaryOnAdd(essay);
  }

  /// 删除随笔
  ///
  /// 同时更新相关标签计数和年度/月度统计信息。
  Future<void> deleteEssay(Essay essay) async {
    await state.essayBox.delete(essay.id);

    // 更新标签计数（标签不存在时跳过）
    for (final labelId in essay.labels) {
      final label = state.labelBox.get(labelId);
      if (label == null) continue;
      await state.labelBox.put(
        labelId,
        label.copyWith(essayCount: label.essayCount - 1),
      );
    }

    // 更新年度统计（年度汇总缺失时跳过）
    final yearSummary = state.summaryBox.get(essay.date.year.toString());
    if (yearSummary == null) return;
    await state.summaryBox.put(
      yearSummary.year,
      yearSummary.edit(essay: essay, isAppend: false),
    );
  }

  /// 更新年度统计（添加随笔时）
  Future<void> _updateYearSummaryOnAdd(Essay essay) async {
    final yearKey = essay.date.year.toString();
    final yearSummary = state.summaryBox.get(yearKey);

    if (yearSummary == null) {
      // 创建新年度统计
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
      );
      await state.summaryBox.put(yearKey, newYearSummary);
    } else {
      // 更新现有年度统计
      await state.summaryBox.put(
        yearKey,
        yearSummary.edit(essay: essay, isAppend: true),
      );
    }
  }
  /// 对某篇随笔的标签进行切换（添加/移除）
  ///
  /// 确保每篇随笔至少有一个标签。
  Future<void> retag(String essayId, String labelId) async {    final originalEssay = state.essayBox.get(essayId);
    final originalLabel = state.labelBox.get(labelId);
    if (originalEssay == null || originalLabel == null) return;

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

    final updatedEssay = originalEssay.copyWith(labels: updatedLabels);
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
    if (originalEssay == null) return;

    final updatedMessages = List<Message>.from(originalEssay.messages)
      ..add(message);
    final essay = originalEssay.copyWith(messages: updatedMessages);
    await state.essayBox.put(essay.id, essay);

    // 更新当前显示的随笔
    ref.read(contentServerProvider.notifier).switchEssay(essay);
  }

  /// 新增标签
  Future<void> addLabel(String name) async {
    final label = Label.newOne(name);
    await state.labelBox.put(label.id, label);
  }

  /// 删除没有任何随笔引用的标签
  ///
  /// 以随笔实际引用为准而非标签上的计数，避免误删仍被引用的标签。
  Future<void> deleteZeroLabels() async {
    final referenced = <String>{};
    for (final essay in state.essayBox.values) {
      referenced.addAll(essay.labels);
    }

    final orphans = state.labelBox.values
        .where((label) => !referenced.contains(label.id))
        .map((label) => label.id)
        .toList();
    if (orphans.isNotEmpty) {
      await state.labelBox.deleteAll(orphans);
    }
  }
  /// 从服务器同步数据（整体替换本地数据）
  ///
  /// 先把全部数据解析校验完，再清空并写入本地：任何一条数据非法都直接抛出，
  /// 不会留下"已清空但未导入"的空库。
  /// 图片下载由 TransferController 统一处理（带进度），此处仅导入数据。
  Future<void> syncData(dynamic json) async {
    final summaries = <String, YearSummary>{};
    for (final raw in json['year_summaries'] as List) {
      final summary = YearSummary.fromJson(raw as Map<String, dynamic>);
      summaries[summary.year] = summary;
    }

    final labels = <String, Label>{};
    for (final raw in json['labels'] as List) {
      final label = Label.fromJson(raw as Map<String, dynamic>);
      labels[label.id] = label;
    }

    final essays = <String, Essay>{};
    for (final raw in json['essays'] as List) {
      final essay = Essay.fromJson(raw as Map<String, dynamic>);
      essays[essay.id] = essay;
    }

    await state.summaryBox.clear();
    await state.labelBox.clear();
    await state.essayBox.clear();
    await state.summaryBox.putAll(summaries);
    await state.labelBox.putAll(labels);
    await state.essayBox.putAll(essays);
  }

  /// 打包本地数据用于备份
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

    return {
      "jsonData": jsonEncode({
        "year_summaries": yearSummaries,
        "labels": labels,
        "essays": essays,
      }),
    };
  }

  /// 获取所有随笔图片的相对路径
  List<String> getImgsPath() {
    final urls = <String>[];
    for (final essay in state.essayBox.values) {
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
