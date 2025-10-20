import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/essay/models/essay.dart';

part 'setting_provider.g.dart';


// ----浏览设置类----
class BrowseSettings {
  final SortType sortType;
  final List<String> selectedLabels;

  BrowseSettings({
    this.sortType = SortType.descending,
    this.selectedLabels = const [],
  });

  BrowseSettings copyWith({SortType? sortType, List<String>? selectedLabels}) {
    return BrowseSettings(
      sortType: sortType ?? this.sortType,
      selectedLabels: selectedLabels ?? this.selectedLabels,
    );
  }
}

enum SortType { ascending, descending, random }

// 浏览设置提供者
@riverpod
class BrowseManager extends _$BrowseManager {
  @override
  BrowseSettings build() {
    return BrowseSettings();
  }

  void setSortType(SortType sortType) {
    state = state.copyWith(sortType: sortType);
  }

  void toggleLabel(String labelId) {
    final selectedLabels = List<String>.from(state.selectedLabels);
    if (selectedLabels.contains(labelId)) {
      selectedLabels.remove(labelId);
    } else {
      selectedLabels.add(labelId);
    }
    state = state.copyWith(selectedLabels: selectedLabels);
  }

  void clearFilters() {
    state = BrowseSettings();
  }
}

// ----方便呈现的当前浏览essay----
@riverpod
class ContentServer extends _$ContentServer {
  @override
  Essay? build() {
    return null;
  }

  void switchEssay(Essay essay) {
    state = essay.copyWith();
  }
}