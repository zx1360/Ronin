import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/essay/models/essay.dart';
import 'package:torrid/features/essay/models/label.dart';
import 'package:torrid/features/essay/models/label_tree.dart';
import 'package:torrid/features/essay/models/year_summary.dart';
import 'package:torrid/features/essay/providers/essay_data_provider.dart';
import 'package:torrid/features/essay/providers/setting_provider.dart';

part 'status_provider.g.dart';

@riverpod
List<Label> labels(Ref ref) {
  final source = ref.watch(labelStreamProvider).value ?? [];
  final essays = ref.watch(essayStreamProvider).value ?? [];
  return countEssayLabels(visibleEssays(essays, source), source)
    ..sort((a, b) => b.essayCount.compareTo(a.essayCount));
}

@riverpod
Map<String, String> idMap(Ref ref) =>
    labelPaths(ref.watch(labelStreamProvider).value ?? []);

@riverpod
List<YearSummary> summaries(Ref ref) {
  final essays = ref.watch(essayStreamProvider).value ?? [];
  final allLabels = ref.watch(labelStreamProvider).value ?? [];
  return YearSummary.groupByYear(
    visibleEssays(essays, allLabels),
  ).values.toList()..sort((a, b) => b.year.compareTo(a.year));
}

@riverpod
List<String> browseYears(Ref ref) {
  final essays = ref.watch(essayStreamProvider).value ?? const [];
  final showHidden = ref.watch(
    browseManagerProvider.select((s) => s.showHidden),
  );
  final hidden = showHidden
      ? const <String>{}
      : hiddenLabelIds(ref.watch(labelStreamProvider).value ?? const []);
  final years = {
    for (final essay in essays)
      if (!essay.labels.any(hidden.contains)) essay.year,
  }.toList()..sort((a, b) => b.compareTo(a));
  return [for (final year in years) year.toString()];
}

Set<String> _expandFilter(
  List<Label> labels,
  Map<String, LabelFilterMode> filter,
) {
  final ids = <String>{};
  final roots = <String>[];
  for (final label in labels) {
    switch (filter[label.id]) {
      case LabelFilterMode.subtree:
        roots.add(label.id);
      case LabelFilterMode.direct:
        ids.add(label.id);
      case null:
        break;
    }
  }
  if (roots.isNotEmpty) ids.addAll(labelSubtree(labels, roots));
  return ids;
}

@riverpod
Future<List<Essay>> filteredEssays(Ref ref) async {
  final settings = ref.watch(browseManagerProvider);
  final source = ref.watch(essayStreamProvider.future);
  final allLabels = await ref.watch(labelStreamProvider.future);
  final hidden = settings.showHidden
      ? const <String>{}
      : hiddenLabelIds(allLabels);
  final selectable = allLabels
      .where((label) => !hidden.contains(label.id))
      .toList();
  final included = _expandFilter(selectable, settings.selectedLabels);
  final excluded = _expandFilter(selectable, settings.excludedLabels);
  final filtered = [
    for (final item in await source)
      if (!item.labels.any(hidden.contains) &&
          (included.isEmpty || item.labels.any(included.contains)) &&
          !item.labels.any(excluded.contains))
        item,
  ];

  if (settings.sortType == SortType.random) {
    filtered.sort((a, b) {
      final order = Object.hash(
        a.id,
        settings.randomSeed,
      ).compareTo(Object.hash(b.id, settings.randomSeed));
      return order == 0 ? a.id.compareTo(b.id) : order;
    });
  } else if (settings.sortType == SortType.ascending) {
    filtered.sort((a, b) {
      final order = a.date.compareTo(b.date);
      return order == 0 ? a.id.compareTo(b.id) : order;
    });
  }
  return filtered;
}

@riverpod
FutureOr<List<Essay>> yearEssays(Ref ref, {required String year}) {
  final targetYear = int.tryParse(year);
  List<Essay> selectYear(List<Essay> essays) => [
    for (final essay in essays)
      if (essay.year == targetYear) essay,
  ];

  final filtered = ref.watch(filteredEssaysProvider).asData;
  if (filtered != null && !filtered.isLoading) {
    return selectYear(filtered.value);
  }
  return ref.watch(filteredEssaysProvider.future).then(selectYear);
}
