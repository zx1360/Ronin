import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/transformers.dart';

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
Stream<List<Style>> styleStream(StyleStreamRef ref) {
  final box = ref.read(styleBoxProvider);
  // 当Box内容变化, 重新推送所有记录. (初次绑定监听时先发送一次事件触发数据发射).
  return box
      .watch()
      .startWith(BoxEvent(box.name, null, false))
      .map((_) => box.values.toList());
}

// record流
@riverpod
Box<Record> recordBox(RecordBoxRef ref) {
  return Hive.box(HiveService.recordBoxName);
}

@riverpod
Stream<List<Record>> recordStream(RecordStreamRef ref) {
  final box = ref.read(recordBoxProvider);
  return box
      .watch()
      .startWith(BoxEvent(box.name, null, false))
      .map((_) => box.values.toList());
}
