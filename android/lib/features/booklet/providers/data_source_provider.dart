import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:torrid/core/services/storage/hive_service.dart';
import 'package:torrid/features/booklet/models/record.dart';
import 'package:torrid/features/booklet/models/style.dart';

part 'data_source_provider.g.dart';

@riverpod
Box<Style> styleBox(StyleBoxRef ref) {
  return Hive.box(HiveService.styleBoxName);
}

@riverpod
Box<Record> recordBox(RecordBoxRef ref) {
  return Hive.box(HiveService.recordBoxName);
}

@riverpod
Stream<List<Style>> styleStream(StyleStreamRef ref) async* {
  final box = ref.read(styleBoxProvider);
  yield box.values.toList();
  await for (final event in box.watch()) {
    if (event.deleted || event.value != null) {
      yield box.values.toList();
    }
  }
}

@riverpod
Stream<List<Record>> recordStream(RecordStreamRef ref) async* {
  final box = ref.read(recordBoxProvider);
  yield box.values.toList();
  await for (final event in box.watch()) {
    if (event.deleted || event.value != null) {
      yield box.values.toList();
    }
  }
}

@riverpod
List<Style> allStyles(AllStylesRef ref) {
  final asyncVal = ref.watch(styleStreamProvider);
  if (asyncVal.hasError) {
    throw asyncVal.error!;
  }
  return asyncVal.asData?.value ?? [];
}

@riverpod
List<Record> allRecords(AllRecordsRef ref) {
  final asyncVal = ref.watch(recordStreamProvider);
  if (asyncVal.hasError) {
    throw asyncVal.error!;
  }
  return asyncVal.asData?.value ?? [];
}
