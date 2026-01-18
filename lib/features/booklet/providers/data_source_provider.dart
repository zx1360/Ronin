import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:torrid/core/services/storage/hive_service.dart';
import 'package:torrid/features/booklet/models/record.dart';
import 'package:torrid/features/booklet/models/style.dart';

part 'data_source_provider.g.dart';

/// ============================================================================
/// Booklet 模块数据源层
/// 负责 Hive Box 的访问和数据流的提供
/// ============================================================================

// ==================== Hive Box Providers ====================

/// Style Box Provider - 提供 Style 数据的 Hive Box 访问
@riverpod
Box<Style> styleBox(StyleBoxRef ref) {
  return Hive.box(HiveService.styleBoxName);
}

/// Record Box Provider - 提供 Record 数据的 Hive Box 访问
@riverpod
Box<Record> recordBox(RecordBoxRef ref) {
  return Hive.box(HiveService.recordBoxName);
}

// ==================== 数据流 Providers ====================

/// Style 数据流 - 监听 Box 变化，实时推送最新数据
@riverpod
Stream<List<Style>> styleStream(StyleStreamRef ref) async* {
  final box = ref.read(styleBoxProvider);
  // 初始推送当前数据
  yield box.values.toList();
  // 监听变化并推送更新
  await for (final event in box.watch()) {
    if (event.deleted || event.value != null) {
      yield box.values.toList();
    }
  }
}

/// Record 数据流 - 监听 Box 变化，实时推送最新数据
@riverpod
Stream<List<Record>> recordStream(RecordStreamRef ref) async* {
  final box = ref.read(recordBoxProvider);
  // 初始推送当前数据
  yield box.values.toList();
  // 监听变化并推送更新
  await for (final event in box.watch()) {
    if (event.deleted || event.value != null) {
      yield box.values.toList();
    }
  }
}

// ==================== 基础数据 Providers ====================

/// 所有 Style 列表 - 同步访问接口
@riverpod
List<Style> allStyles(AllStylesRef ref) {
  final asyncVal = ref.watch(styleStreamProvider);
  if (asyncVal.hasError) {
    throw asyncVal.error!;
  }
  return asyncVal.asData?.value ?? [];
}

/// 所有 Record 列表 - 同步访问接口
@riverpod
List<Record> allRecords(AllRecordsRef ref) {
  final asyncVal = ref.watch(recordStreamProvider);
  if (asyncVal.hasError) {
    throw asyncVal.error!;
  }
  return asyncVal.asData?.value ?? [];
}
