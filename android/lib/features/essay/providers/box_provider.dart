/// Essay 模块的 Hive Box 提供者
///
/// 提供对 [YearSummary]、[Essay]、[Label] 三种数据的 Box 访问和响应式流。
library;

import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:torrid/core/services/storage/hive_service.dart';
import 'package:torrid/features/essay/models/essay.dart';
import 'package:torrid/features/essay/models/label.dart';
import 'package:torrid/features/essay/models/year_summary.dart';

part 'box_provider.g.dart';

// ============================================================================
// YearSummary Box & Stream
// ============================================================================

/// 年度统计信息的 Hive Box
@riverpod
Box<YearSummary> summaryBox(SummaryBoxRef ref) {
  return Hive.box<YearSummary>(HiveService.yearSummaryBoxName);
}

/// 年度统计信息的响应式流
/// 
/// 使用 yield 手动触发一次以读取初始数据，之后监听 box 变化。
@riverpod
Stream<List<YearSummary>> summaryStream(SummaryStreamRef ref) async* {
  final box = ref.read(summaryBoxProvider);
  yield box.values.toList();
  await for (final event in box.watch()) {
    if (event.deleted || event.value != null) {
      yield box.values.toList();
    }
  }
}

// ============================================================================
// Essay Box & Stream
// ============================================================================

/// 随笔数据的 Hive Box
@riverpod
Box<Essay> essayBox(EssayBoxRef ref) {
  return Hive.box<Essay>(HiveService.essayBoxName);
}

/// 随笔数据的响应式流
@riverpod
Stream<List<Essay>> essayStream(EssayStreamRef ref) async* {
  final box = ref.read(essayBoxProvider);
  yield box.values.toList();
  await for (final event in box.watch()) {
    if (event.deleted || event.value != null) {
      yield box.values.toList();
    }
  }
}

// ============================================================================
// Label Box & Stream
// ============================================================================

/// 标签数据的 Hive Box
@riverpod
Box<Label> labelBox(LabelBoxRef ref) {
  return Hive.box<Label>(HiveService.labelBoxName);
}

/// 标签数据的响应式流
@riverpod
Stream<List<Label>> labelStream(LabelStreamRef ref) async* {
  final box = ref.read(labelBoxProvider);
  yield box.values.toList();
  await for (final event in box.watch()) {
    if (event.deleted || event.value != null) {
      yield box.values.toList();
    }
  }
}