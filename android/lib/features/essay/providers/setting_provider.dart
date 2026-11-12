import 'dart:math';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'setting_provider.g.dart';

enum SortType { ascending, descending, random }

enum LabelFilterMode { subtree, direct }

class BrowseSettings {
  final SortType sortType;
  final int randomSeed;
  final Map<String, LabelFilterMode> selectedLabels;
  final Map<String, LabelFilterMode> excludedLabels;
  final bool showHidden;

  const BrowseSettings({
    this.sortType = SortType.descending,
    this.randomSeed = 0,
    this.selectedLabels = const {},
    this.excludedLabels = const {},
    this.showHidden = false,
  });

  BrowseSettings copyWith({
    SortType? sortType,
    int? randomSeed,
    Map<String, LabelFilterMode>? selectedLabels,
    Map<String, LabelFilterMode>? excludedLabels,
    bool? showHidden,
  }) => BrowseSettings(
    sortType: sortType ?? this.sortType,
    randomSeed: randomSeed ?? this.randomSeed,
    selectedLabels: selectedLabels ?? this.selectedLabels,
    excludedLabels: excludedLabels ?? this.excludedLabels,
    showHidden: showHidden ?? this.showHidden,
  );

  bool get hasFilters =>
      selectedLabels.isNotEmpty || excludedLabels.isNotEmpty || showHidden;
}

@riverpod
class BrowseManager extends _$BrowseManager {
  @override
  BrowseSettings build() => const BrowseSettings();

  void setSortType(SortType sortType) => state = state.copyWith(
    sortType: sortType,
    randomSeed: sortType == SortType.random ? Random().nextInt(1 << 31) : null,
  );

  void setShowHidden(bool value, Set<String> hiddenIds) {
    state = state.copyWith(
      showHidden: value,
      selectedLabels: value
          ? null
          : (Map.of(state.selectedLabels)
              ..removeWhere((id, _) => hiddenIds.contains(id))),
      excludedLabels: value
          ? null
          : (Map.of(state.excludedLabels)
              ..removeWhere((id, _) => hiddenIds.contains(id))),
    );
  }

  void toggleLabel(
    String id, {
    required bool hasChildren,
    required bool exclude,
  }) {
    final included = Map.of(state.selectedLabels);
    final excluded = Map.of(state.excludedLabels);
    final current = exclude ? excluded : included;
    switch (current[id]) {
      case null:
        (exclude ? included : excluded).remove(id);
        current[id] = hasChildren
            ? LabelFilterMode.subtree
            : LabelFilterMode.direct;
      case LabelFilterMode.subtree:
        current[id] = LabelFilterMode.direct;
      case LabelFilterMode.direct:
        current.remove(id);
    }
    state = state.copyWith(selectedLabels: included, excludedLabels: excluded);
  }

  void removeLabel(String id, {required bool exclude}) {
    state = exclude
        ? state.copyWith(
            excludedLabels: Map.of(state.excludedLabels)..remove(id),
          )
        : state.copyWith(
            selectedLabels: Map.of(state.selectedLabels)..remove(id),
          );
  }

  void clearFilters() => state = state.copyWith(
    selectedLabels: {},
    excludedLabels: {},
    showHidden: false,
  );
}
