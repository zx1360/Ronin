import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/booklet/models/record.dart';
import 'package:torrid/features/booklet/models/style.dart';

part 'box_provider.g.dart';

// Hive盒子提供者.
@riverpod
Box<Style> styleBox(StyleBoxRef ref) {
  return Hive.box("styles");
}

@riverpod
Box<Record> recordBox(RecordBoxRef ref) {
  return Hive.box("records");
}