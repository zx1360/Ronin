/// Essay 模块的设置与状态管理
///
/// 包含浏览设置管理 [BrowseManager] 和当前选中随笔 [SelectedEssay]。
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/essay/models/essay.dart';

part 'setting_provider.g.dart';

// ============================================================================
// 浏览设置
// ============================================================================

/// 随笔排序方式
enum SortType { 
  /// 按时间升序（旧→新）
  ascending, 
  /// 按时间降序（新→旧）
  descending, 
  /// 随机排序
  random,
}

/// 浏览设置状态
/// 
/// 包含排序方式和已选标签筛选条件。
class BrowseSettings {
  /// 当前排序方式
  final SortType sortType;
  
  /// 已选中的标签ID列表（用于筛选）
  final List<String> selectedLabels;

  const BrowseSettings({
    this.sortType = SortType.descending,
    this.selectedLabels = const [],
  });

  BrowseSettings copyWith({
    SortType? sortType, 
    List<String>? selectedLabels,
  }) {
    return BrowseSettings(
      sortType: sortType ?? this.sortType,
      selectedLabels: selectedLabels ?? this.selectedLabels,
    );
  }
  
  /// 是否有筛选条件
  bool get hasFilters => selectedLabels.isNotEmpty;
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

  /// 切换标签选中状态
  void toggleLabel(String labelId) {
    final selectedLabels = List<String>.from(state.selectedLabels);
    if (selectedLabels.contains(labelId)) {
      selectedLabels.remove(labelId);
    } else {
      selectedLabels.add(labelId);
    }
    state = state.copyWith(selectedLabels: selectedLabels);
  }

  /// 清除所有筛选条件
  void clearFilters() {
    state = const BrowseSettings();
  }
}

// ============================================================================
// 当前选中的随笔
// ============================================================================

/// 当前选中/正在查看的随笔
/// 
/// 用于详情页和相关操作时保持当前随笔的引用。
/// 
/// **重命名说明**: 原名 `ContentServer`，为提高可读性重命名为 `SelectedEssay`。
/// 生成的 provider 名称保持 `contentServerProvider` 以保持向后兼容。
@Riverpod(keepAlive: false)
class ContentServer extends _$ContentServer {
  @override
  Essay? build() => null;

  /// 切换当前选中的随笔
  void switchEssay(Essay essay) {
    state = essay.copyWith();
  }
  
  /// 清除当前选中
  void clear() {
    state = null;
  }
}
