import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'setting_provider.g.dart';

/// 随笔排序方式
enum SortType {
  /// 按时间升序（旧→新）
  ascending,

  /// 按时间降序（新→旧）
  descending,

  /// 随机排序
  random,
}

enum LabelFilterMode { subtree, direct }

/// 浏览设置状态
///
/// 包含排序方式和已选标签筛选条件。
class BrowseSettings {
  /// 当前排序方式
  final SortType sortType;

  final Map<String, LabelFilterMode> selectedLabels;
  final bool showHidden;

  const BrowseSettings({
    this.sortType = SortType.descending,
    this.selectedLabels = const {},
    this.showHidden = false,
  });

  BrowseSettings copyWith({
    SortType? sortType,
    Map<String, LabelFilterMode>? selectedLabels,
    bool? showHidden,
  }) {
    return BrowseSettings(
      sortType: sortType ?? this.sortType,
      selectedLabels: selectedLabels ?? this.selectedLabels,
      showHidden: showHidden ?? this.showHidden,
    );
  }

  /// 是否有筛选条件
  bool get hasFilters => selectedLabels.isNotEmpty || showHidden;
}

/// 浏览设置管理器
///
/// 管理随笔浏览页面的排序和筛选设置。
@riverpod
class BrowseManager extends _$BrowseManager {
  @override
  BrowseSettings build() => const BrowseSettings();

  /// 设置排序方式
  void setSortType(SortType sortType) {
    state = state.copyWith(sortType: sortType);
  }

  void setShowHidden(bool value, Set<String> hiddenIds) {
    state = state.copyWith(
      showHidden: value,
      selectedLabels: value
          ? state.selectedLabels
          : (Map.of(state.selectedLabels)
              ..removeWhere((id, _) => hiddenIds.contains(id))),
    );
  }

  void toggleLabel(String labelId, {required bool hasChildren}) {
    final selected = Map.of(state.selectedLabels);
    switch (selected[labelId]) {
      case null:
        selected[labelId] = hasChildren
            ? LabelFilterMode.subtree
            : LabelFilterMode.direct;
      case LabelFilterMode.subtree:
        selected[labelId] = LabelFilterMode.direct;
      case LabelFilterMode.direct:
        selected.remove(labelId);
    }
    state = state.copyWith(selectedLabels: selected);
  }

  void removeLabel(String labelId) {
    state = state.copyWith(
      selectedLabels: Map.of(state.selectedLabels)..remove(labelId),
    );
  }

  /// 清除所有筛选条件
  void clearFilters() {
    state = const BrowseSettings();
  }
}
