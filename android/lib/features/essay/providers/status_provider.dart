/// Essay 模块的派生状态提供者
///
/// 基于 Box 数据流提供经过处理的同步数据访问。
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/essay/models/essay.dart';
import 'package:torrid/features/essay/models/label.dart';
import 'package:torrid/features/essay/models/year_summary.dart';
import 'package:torrid/features/essay/providers/box_provider.dart';
import 'package:torrid/features/essay/providers/setting_provider.dart';

part 'status_provider.g.dart';

// ============================================================================
// 标签数据
// ============================================================================

/// 所有标签列表（按随笔数量降序排列）
@riverpod
List<Label> labels(LabelsRef ref) {
  final asyncVal = ref.watch(labelStreamProvider);
  if (asyncVal.hasError) {
    throw asyncVal.error!;
  }
  final labels = asyncVal.asData?.value ?? [];
  return labels..sort((a, b) => b.essayCount.compareTo(a.essayCount));
}

/// 标签 ID 到名称的映射表
/// 
/// 便于在显示时快速查找标签名称。
@riverpod
Map<String, String> idMap(IdMapRef ref) {
  final allLabels = ref.watch(labelsProvider);
  return {for (final label in allLabels) label.id: label.name};
}

// ============================================================================
// 年度统计数据
// ============================================================================

/// 所有年度统计数据（按年份降序排列）
/// 
/// 每个年度内的月份数据按月份升序排列。
@riverpod
List<YearSummary> summaries(SummariesRef ref) {
  final asyncVal = ref.watch(summaryStreamProvider);
  if (asyncVal.hasError) {
    throw asyncVal.error!;
  }
  final summaries = asyncVal.asData?.value ?? [];
  
  // 对每个年度的月份数据进行排序
  for (final summary in summaries) {
    summary.monthSummaries.sort(
      (a, b) => int.parse(a.month).compareTo(int.parse(b.month)),
    );
  }

  // 年度按降序排列
  return summaries
    ..sort((a, b) => int.parse(b.year).compareTo(int.parse(a.year)));
}

// ============================================================================
// 筛选后的随笔数据
// ============================================================================

/// 经过筛选和排序的随笔列表
/// 
/// 根据 [BrowseManager] 的设置进行标签筛选和排序。
@riverpod
Future<List<Essay>> filteredEssays(FilteredEssaysRef ref) async {
  final essays = await ref.watch(essayStreamProvider.future);
  final settings = ref.watch(browseManagerProvider);

  List<Essay> filtered = essays;
  
  // 按标签筛选
  if (settings.selectedLabels.isNotEmpty) {
    filtered = filtered.where((essay) {
      return settings.selectedLabels.any(
        (labelId) => essay.labels.contains(labelId),
      );
    }).toList();
  }

  // 按设置排序
  switch (settings.sortType) {
    case SortType.ascending:
      filtered.sort((a, b) => a.date.compareTo(b.date));
    case SortType.descending:
      filtered.sort((a, b) => b.date.compareTo(a.date));
    case SortType.random:
      filtered.shuffle();
  }

  return filtered;
}

/// 指定年份的随笔列表（基于筛选结果）
@riverpod
Future<List<Essay>> yearEssays(
  YearEssaysRef ref, {
  required String year,
}) async {
  final filteredEssays = await ref.watch(filteredEssaysProvider.future);
  return filteredEssays
      .where((essay) => essay.year.toString() == year)
      .toList();
}
