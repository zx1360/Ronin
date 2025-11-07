// Hive 盒子提供者
import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:torrid/services/storage/hive_service.dart';
import 'package:torrid/features/essay/models/essay.dart';
import 'package:torrid/features/essay/models/label.dart';
import 'package:torrid/features/essay/models/year_summary.dart';

part 'box_provider.g.dart';

// yearSummaries流
@riverpod
Box<YearSummary> summaryBox(SummaryBoxRef ref){
  return Hive.box<YearSummary>(HiveService.yearSummaryBoxName);
}

// 使用.startWith手动触发一次, 读取到原先的数据.
@riverpod
Stream<List<YearSummary>> summaryStream(SummaryStreamRef ref) async* {
  final box = ref.read(summaryBoxProvider);
  yield box.values.toList();
  await for(final event in box.watch()){
    if(event.deleted||event.value!=null){
      yield box.values.toList();
    }
  }
}

// essays流
@riverpod
Box<Essay> essayBox(EssayBoxRef ref){
  return Hive.box<Essay>(HiveService.essayBoxName);
}

@riverpod
Stream<List<Essay>> essayStream(EssayStreamRef ref) async* {
  final box = ref.read(essayBoxProvider);
  yield box.values.toList();
  await for(final event in box.watch()){
    if(event.deleted||event.value!=null){
      yield box.values.toList();
    }
  }
}

// labels流
@riverpod
Box<Label> labelBox(LabelBoxRef ref){
  return Hive.box<Label>(HiveService.labelBoxName);
}

@riverpod
Stream<List<Label>> labelStream(LabelStreamRef ref) async* {
  final box = ref.read(labelBoxProvider);
  yield box.values.toList();
  await for(final event in box.watch()){
    if(event.deleted||event.value!=null){
      yield box.values.toList();
    }
  }
}