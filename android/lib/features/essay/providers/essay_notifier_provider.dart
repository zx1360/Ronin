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

// ============================================================================
// 数据仓库
// ============================================================================

/// Essay 模块的数据仓库
///
/// 封装对 [YearSummary]、[Essay]、[Label] 三个 Box 的访问。
///
/// **重构说明**: 原名 `Cashier`，重命名为语义更清晰的 `EssayRepository`。
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

// ============================================================================
// Essay 服务
// ============================================================================

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

  // --------------------------------------------------------------------------
  // 统计信息刷新
  // --------------------------------------------------------------------------

  /// 刷新所有年度统计信息
  ///
  /// 遍历所有年度，根据当前随笔数据重新计算统计信息。
  /// 如果某年度没有随笔，则删除该年度记录。
  Future<void> refreshYear() async {
    final allEssays = state.essayBox.values;
    for (final yearSummary in state.summaryBox.values.toList()) {
      final refreshed = YearSummary.fromEssays(yearSummary.year, allEssays);
      if (refreshed.essayCount > 0) {
        await state.summaryBox.put(yearSummary.year, refreshed);
      } else {
        await state.summaryBox.delete(yearSummary.year);
      }
    }
  }

  /// 刷新所有标签的随笔计数
  Future<void> refreshLabel() async {
    for (final label in state.labelBox.values) {
      final essayCount = state.essayBox.values
          .where((essay) => essay.labels.contains(label.id))
          .length;
      if (label.essayCount > 0) {
        await state.labelBox.put(
          label.id,
          label.copyWith(essayCount: essayCount),
        );
      }
    }
  }

  // --------------------------------------------------------------------------
  // 随笔 CRUD
  // --------------------------------------------------------------------------

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

  // --------------------------------------------------------------------------
  // 标签管理
  // --------------------------------------------------------------------------

  /// 对某篇随笔的标签进行切换（添加/移除）
  ///
  /// 确保每篇随笔至少有一个标签。
  Future<void> retag(String essayId, String labelId) async {
    final originalEssay = state.essayBox.get(essayId);
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

  /// 删除所有随笔数为 0 的标签
  Future<void> deleteZeroLabels() async {
    final zeroLabels = state.labelBox.values
        .where((label) => label.essayCount == 0)
        .map((l) => l.id);
    await state.labelBox.deleteAll(zeroLabels);
  }

  // --------------------------------------------------------------------------
  // 数据同步与备份
  // --------------------------------------------------------------------------

  /// 从服务器同步数据
  ///
  /// 清空本地数据后导入服务器数据。
  /// 注意：图片下载由 TransferController._downloadImages 统一处理（带进度），此处仅导入数据。
  Future<void> syncData(dynamic json) async {
    await state.summaryBox.clear();
    await state.labelBox.clear();
    await state.essayBox.clear();

    // 导入年度统计
    for (final yearSummary in (json['year_summaries'] as List)) {
      await state.summaryBox.put(
        yearSummary['year'],
        YearSummary.fromJson(yearSummary as Map<String, dynamic>),
      );
    }

    // 导入标签（需要建立 ID 映射）
    final Map<String, String> labelIdMap = {};
    for (final label in (json['labels'] as List)) {
      final labelData = label as Map<String, dynamic>;
      final newLabel = Label.fromJson(labelData);
      labelIdMap[labelData['id'] as String] = newLabel.id;
      await state.labelBox.put(newLabel.id, newLabel);
    }

    // 导入随笔（更新标签引用；缺失标签时保留原 ID，避免空断言崩溃）
    for (final essay in (json['essays'] as List)) {
      var essayData = Essay.fromJson(essay as Map<String, dynamic>);
      essayData = essayData.copyWith(
        labels: essayData.labels
            .map((label) => labelIdMap[label] ?? label)
            .toList(),
      );
      await state.essayBox.put(essayData.id, essayData);
    }
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
