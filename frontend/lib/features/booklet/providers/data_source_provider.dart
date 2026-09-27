import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:torrid/core/api/user_data_sync.dart';
import 'package:torrid/core/services/storage/hive_service.dart';
import 'package:torrid/features/booklet/models/record.dart';
import 'package:torrid/features/booklet/models/style.dart';

part 'data_source_provider.g.dart';

/// 供 UI / 派生统计消费的"活"行：墓碑行只在同步时使用，必须过滤掉。
///
/// Box 里保留墓碑（而不是物理删除）是为了让删除动作能上传到服务端；
/// 一旦在这里漏过滤，已删除的样式/打卡记录会重新出现在界面上。
List<T> _live<T extends SyncRow>(Box<T> box) =>
    liveSyncRows(box.values).toList();

// Hive Box Providers

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

// 数据流 Providers

/// Style 数据流 - 监听 Box 变化，实时推送最新数据（已过滤墓碑）
@riverpod
Stream<List<Style>> styleStream(StyleStreamRef ref) async* {
  final box = ref.read(styleBoxProvider);
  // 初始推送当前数据
  yield _live(box);
  // 监听变化并推送更新
  await for (final event in box.watch()) {
    if (event.deleted || event.value != null) {
      yield _live(box);
    }
  }
}

/// Record 数据流 - 监听 Box 变化，实时推送最新数据（已过滤墓碑）
@riverpod
Stream<List<Record>> recordStream(RecordStreamRef ref) async* {
  final box = ref.read(recordBoxProvider);
  // 初始推送当前数据
  yield _live(box);
  // 监听变化并推送更新
  await for (final event in box.watch()) {
    if (event.deleted || event.value != null) {
      yield _live(box);
    }
  }
}

// 基础数据 Providers

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
