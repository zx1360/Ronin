/// Essay 模块的派生状态提供者
///
/// 基于 Box 数据流提供经过处理的同步数据访问。
/// 这些 provider 都返回副本：Box 流里的列表与对象是共享实例，
/// 就地排序/洗牌会污染其它消费者（随机排序尤其会"渗漏"到所有读取方）。
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/essay/models/essay.dart';
import 'package:torrid/features/essay/models/label.dart';
import 'package:torrid/features/essay/models/label_tree.dart';
import 'package:torrid/features/essay/models/year_summary.dart';
import 'package:torrid/features/essay/providers/box_provider.dart';
import 'package:torrid/features/essay/providers/setting_provider.dart';

part 'status_provider.g.dart';

/// 所有标签列表（按可统计的随笔数量降序排列）
@riverpod
List<Label> labels(LabelsRef ref) {
  final asyncVal = ref.watch(labelStreamProvider);
  if (asyncVal.hasError) {
    throw asyncVal.error!;
  }
  final source =
      asyncVal.asData?.value ?? ref.read(labelBoxProvider).values.toList();
  final essays =
      ref.watch(essayStreamProvider).asData?.value ??
      ref.read(essayBoxProvider).values;
  return countEssayLabels(visibleEssays(essays, source), source)
    ..sort((a, b) => b.essayCount.compareTo(a.essayCount));
}

/// 标签 ID 到名称的映射表
///
/// 便于在显示时快速查找标签名称。
@riverpod
Map<String, String> idMap(IdMapRef ref) {
  final allLabels =
      ref.watch(labelStreamProvider).asData?.value ??
      ref.read(labelBoxProvider).values;
  return labelPaths(allLabels);
}

/// 所有年度统计数据（按年份降序排列，每年内月份按升序排列）
@riverpod
List<YearSummary> summaries(SummariesRef ref) {
  final asyncVal = ref.watch(essayStreamProvider);
  if (asyncVal.hasError) {
    throw asyncVal.error!;
  }
  final source = asyncVal.asData?.value ?? ref.read(essayBoxProvider).values;
  final labels = ref.watch(labelsProvider);
  final visible = visibleEssays(source, labels);
  final sorted = YearSummary.groupByYear(visible).values.toList();

  sorted.sort((a, b) => int.parse(b.year).compareTo(int.parse(a.year)));
  return sorted;
}

/// 经过筛选和排序的随笔列表
///
/// 根据 [BrowseManager] 的设置进行标签筛选和排序。
@riverpod
Future<List<Essay>> filteredEssays(FilteredEssaysRef ref) async {
  final settings = ref.watch(browseManagerProvider);
  final labels = ref.watch(labelsProvider);
  final essays = await ref.watch(essayStreamProvider.future);

  final hidden = settings.showHidden
      ? const <String>{}
      : hiddenLabelIds(labels);
  final filtered = essays.where((e) => !e.labels.any(hidden.contains)).toList();

  if (settings.selectedLabels.isNotEmpty) {
    final selected = <String>{};
    final subtrees = <String>[];
    for (final label in labels) {
      if (hidden.contains(label.id)) continue;
      switch (settings.selectedLabels[label.id]) {
        case LabelFilterMode.subtree:
          subtrees.add(label.id);
        case LabelFilterMode.direct:
          selected.add(label.id);
        case null:
          break;
      }
    }
    if (subtrees.isNotEmpty) selected.addAll(labelSubtree(labels, subtrees));
    if (selected.isNotEmpty) {
      filtered.retainWhere((essay) => essay.labels.any(selected.contains));
    }
  }

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
