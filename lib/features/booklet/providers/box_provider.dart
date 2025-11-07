import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:torrid/services/storage/hive_service.dart';
import 'package:torrid/features/booklet/models/record.dart';
import 'package:torrid/features/booklet/models/style.dart';

part 'box_provider.g.dart';

// 数据源
// style流
@riverpod
Box<Style> styleBox(StyleBoxRef ref) {
  return Hive.box(HiveService.styleBoxName);
}

// TODO: "Stream是Future序列", 有时间了理解一下呢.
@riverpod
Stream<List<Style>> styleStream(StyleStreamRef ref) async* {
  final box = ref.read(styleBoxProvider);
  // 当Box内容变化, 重新推送所有记录.
  yield box.values.toList();
  await for(final event in box.watch()){
    if(event.deleted||event.value!=null){
      yield box.values.toList();
    }
  }
}

// record流
@riverpod
Box<Record> recordBox(RecordBoxRef ref) {
  return Hive.box(HiveService.recordBoxName);
}

@riverpod
Stream<List<Record>> recordStream(RecordStreamRef ref) async* {
  final box = ref.read(recordBoxProvider);
  yield box.values.toList();
  await for(final event in box.watch()){
    if(event.deleted||event.value!=null){
      yield box.values.toList();
    }
  }
}
