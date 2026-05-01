import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:torrid/features/booklet/models/style.dart';
import 'package:torrid/features/booklet/providers/data_source_provider.dart';

part 'style_provider.g.dart';

/// ============================================================================
/// Style 相关的 Providers
/// 提供 Style 数据的查询和派生数据
/// ============================================================================

// ==================== Style 查询 Providers ====================

/// 根据 styleId 获取 Style
@riverpod
Style? styleById(StyleByIdRef ref, String styleId) {
  final allStyles = ref.watch(allStylesProvider);
  try {
    return allStyles.firstWhere((s) => s.id == styleId);
  } catch (_) {
    return null;
  }
}

/// 获取最新的 Style（按创建时间排序）
@riverpod
Style? latestStyle(LatestStyleRef ref) {
  final allStyles = ref.watch(allStylesProvider);
  if (allStyles.isEmpty) return null;
  return allStyles.reduce((a, b) => a.startDate.isAfter(b.startDate) ? a : b);
}

/// 获取按时间倒序排列的所有 Style
@riverpod
List<Style> sortedStyles(SortedStylesRef ref) {
  final allStyles = ref.watch(allStylesProvider);
  return List.from(allStyles)..sort((a, b) => b.startDate.compareTo(a.startDate));
}
