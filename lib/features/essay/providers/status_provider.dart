// 标签列表提供者
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/essay/models/essay.dart';
import 'package:torrid/features/essay/models/label.dart';
import 'package:torrid/features/essay/models/year_summary.dart';
import 'package:torrid/features/essay/providers/box_provider.dart';
import 'package:torrid/features/essay/providers/setting_provider.dart';

part 'status_provider.g.dart';

// ----Stream响应每次的box内容修改, List暴露简单的同步数据.
// essays数据  (labels为id)
@riverpod
List<Essay> essays(EssaysRef ref) {
  final asyncVal = ref.watch(essayStreamProvider);
  if (asyncVal.hasError) {
    throw asyncVal.error!;
  }
  return asyncVal.asData?.value ?? [];
}

@riverpod
List<Label> labels(LabelsRef ref) {
  final asyncVal = ref.watch(labelStreamProvider);
  if (asyncVal.hasError) {
    throw asyncVal.error!;
  }
  final labels = asyncVal.asData?.value ?? [];
  return labels..sort((a, b) => b.essayCount.compareTo(a.essayCount));
}

@riverpod
Map<String, String> idMap(IdMapRef ref) {
  final allLabels = ref.watch(labelsProvider);
  return {for (final label in allLabels) label.id: label.name};
}

// 随笔总览数据提供者
@riverpod
List<YearSummary> summaries(SummariesRef ref) {
  final asyncVal = ref.watch(summaryStreamProvider);
  if (asyncVal.hasError) {
    throw asyncVal.error!;
  }
  final summaries = asyncVal.asData?.value ?? [];
  // 按时间降序.
  for (final summary in summaries) {
    summary.monthSummaries.sort(
      (a, b) => int.parse(a.month).compareTo(int.parse(b.month)),
    );
  }

  return summaries
    ..sort((a, b) => int.parse(b.year).compareTo(int.parse(a.year)));
}

// 过滤后的随笔列表提供者
@riverpod
List<Essay> filteredEssays(FilteredEssaysRef ref) {
  final essays = ref.watch(essaysProvider);
  final settings = ref.watch(browseManagerProvider);

  // 过滤标签
  List<Essay> filtered = essays;
  if (settings.selectedLabels.isNotEmpty) {
    filtered = filtered.where((essay) {
      return settings.selectedLabels.any(
        (labelId) => essay.labels.contains(labelId),
      );
    }).toList();
  }

  // 排序
  switch (settings.sortType) {
    case SortType.ascending:
      filtered.sort((a, b) => a.date.compareTo(b.date));
      break;
    case SortType.descending:
      filtered.sort((a, b) => b.date.compareTo(a.date));
      break;
    case SortType.random:
      filtered.shuffle();
      break;
  }

  return List.of(filtered);
}

// 指定年份的随笔列表提供者（基于筛选结果）
@riverpod
List<Essay> yearEssays(YearEssaysRef ref, {required String year}) {
  // 先获取筛选后的随笔列表
  final filteredEssays = ref.watch(filteredEssaysProvider);

  // 筛选出指定年份的随笔
  return filteredEssays
      .where((essay) => essay.year.toString() == year)
      .toList();
}
