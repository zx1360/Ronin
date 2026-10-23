import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:torrid/features/booklet/models/style.dart';
import 'package:torrid/features/booklet/providers/data_source_provider.dart';

part 'style_provider.g.dart';

/// 根据 styleId 获取 Style
@riverpod
Style? styleById(StyleByIdRef ref, String styleId) {
  final allStyles = ref.watch(allStylesProvider);
  return allStyles.where((style) => style.id == styleId).firstOrNull;
}

/// 获取最新的 Style（按创建时间排序）
@riverpod
Style? latestStyle(LatestStyleRef ref) {
  return ref.watch(sortedStylesProvider).firstOrNull;
}

/// 获取按时间倒序排列的所有 Style
@riverpod
List<Style> sortedStyles(SortedStylesRef ref) {
  final allStyles = ref.watch(allStylesProvider);
  return List<Style>.of(allStyles)..sort((a, b) {
    final date = b.startDate.compareTo(a.startDate);
    if (date != 0) return date;
    final version = (b.updatedAt?.millisecondsSinceEpoch ?? 0).compareTo(
      a.updatedAt?.millisecondsSinceEpoch ?? 0,
    );
    return version != 0 ? version : a.id.compareTo(b.id);
  });
}
