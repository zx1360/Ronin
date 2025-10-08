import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/essay.dart';
import '../models/label.dart';
import '../models/year_summary.dart';

// Hive 盒子提供者
final essaysBoxProvider = Provider<Box<Essay>>((ref) {
  return Hive.box<Essay>('essays');
});

final labelsBoxProvider = Provider<Box<Label>>((ref) {
  return Hive.box<Label>('labels');
});


// 标签列表提供者
final labelsProvider = FutureProvider<List<Label>>((ref) async {
  final box = ref.watch(labelsBoxProvider);
  return box.values.toList();
});

// 标签id-name映射表提供者
final labelMapProvider = FutureProvider<Map<String, String>>((ref) async {
  final allLabels = await ref.watch(labelsProvider.future);
  return {
    for (final label in allLabels) label.id: label.name,
  };
});

// 随笔列表提供者
final essaysProvider = FutureProvider<List<Essay>>((ref) async {
  final box = ref.watch(essaysBoxProvider);
  return box.values.toList();
});


// TODO: 没懂但是直接用的东西, 有时间了思考一下呢.
// 1.FutureProvider.  2.此处的操作过程. 3."过滤功能"的riverpod实现.
// 随笔总览数据提供者
final yearSummariesProvider = FutureProvider<List<YearSummary>>((ref) async {
  final essays = await ref.watch(essaysProvider.future);
  
  // 按年份分组
  final Map<String, Map<int, MonthSummary>> yearMap = {};
  
  for (final essay in essays) {
    final yearKey = essay.year.toString();
    final monthKey = essay.month;
    
    // 初始化年份和月份数据
    if (!yearMap.containsKey(yearKey)) {
      yearMap[yearKey] = {};
    }
    
    if (!yearMap[yearKey]!.containsKey(monthKey)) {
      yearMap[yearKey]![monthKey] = MonthSummary(month: monthKey.toString());
    }
    
    // 更新月份数据
    final monthSummary = yearMap[yearKey]![monthKey]!;
    yearMap[yearKey]![monthKey] = MonthSummary(
      month: monthKey.toString(),
      essayCount: monthSummary.essayCount + 1,
      wordCount: monthSummary.wordCount + essay.wordCount,
    );
  }
  
  // 转换为 YearSummary 列表
  return yearMap.entries.map((yearEntry) {
    final year = yearEntry.key;
    final monthSummaries = yearEntry.value.values.toList()
      ..sort((a, b) => int.parse(a.month).compareTo(int.parse(b.month)));
    
    final totalEssayCount = monthSummaries.fold(0, (sum, month) => sum + month.essayCount);
    final totalWordCount = monthSummaries.fold(0, (sum, month) => sum + month.wordCount);
    
    return YearSummary(
      year: year,
      essayCount: totalEssayCount,
      wordCount: totalWordCount,
      monthSummaries: monthSummaries,
    );
  }).toList()
    ..sort((a, b) => int.parse(b.year).compareTo(int.parse(a.year)));
});

// 浏览设置提供者
final browseSettingsProvider = StateNotifierProvider<BrowseSettingsNotifier, BrowseSettings>((ref) {
  return BrowseSettingsNotifier();
});

class BrowseSettings {
  final SortType sortType;
  final List<String> selectedLabels;
  
  BrowseSettings({
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
}

enum SortType {
  ascending,
  descending,
  random,
}

class BrowseSettingsNotifier extends StateNotifier<BrowseSettings> {
  BrowseSettingsNotifier() : super(BrowseSettings());
  
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
    print(selectedLabels);
    state = state.copyWith(selectedLabels: selectedLabels);
  }
  
  void clearFilters() {
    state = BrowseSettings();
  }
}

// 过滤后的随笔列表提供者
final filteredEssaysProvider = FutureProvider<List<Essay>>((ref) async {
  final essays = await ref.watch(essaysProvider.future);
  final settings = ref.watch(browseSettingsProvider);
  
  // 过滤标签
  List<Essay> filtered = essays;
  if (settings.selectedLabels.isNotEmpty) {
    filtered = filtered.where((essay) {
      print(essay.labels);
      print(settings.selectedLabels);
      return essay.labels.any((labelId) => settings.selectedLabels.contains(labelId));
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
  
  return filtered;
});

// 指定年份的随笔列表提供者（基于筛选结果）
final yearEssaysProvider = FutureProvider.family<List<Essay>, String>((ref, year) async {
  // 先获取筛选后的随笔列表
  final filteredEssays = await ref.watch(filteredEssaysProvider.future);

  // 筛选出指定年份的随笔
  return filteredEssays
      .where((essay) => essay.year.toString() == year)
      .toList();
});
