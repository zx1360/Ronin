// Hive 盒子提供者
import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/transformers.dart';

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

@riverpod
Stream<List<YearSummary>> summaryStream(SummaryStreamRef ref) {
  final box = ref.read(summaryBoxProvider);
  return box
      .watch()
      .startWith(BoxEvent(box.name, null, false))
      .map((_) => box.values.toList());
}

// essays流
@riverpod
Box<Essay> essayBox(EssayBoxRef ref){
  return Hive.box<Essay>(HiveService.essayBoxName);
}

@riverpod
Stream<List<Essay>> essayStream(EssayStreamRef ref) {
  final box = ref.read(essayBoxProvider);
  return box
      .watch()
      .startWith(BoxEvent(box.name, null, false))
      .map((_) => box.values.toList());
}

// labels流
@riverpod
Box<Label> labelBox(LabelBoxRef ref){
  return Hive.box<Label>(HiveService.labelBoxName);
}

@riverpod
Stream<List<Label>> labelStream(LabelStreamRef ref) {
  final box = ref.read(labelBoxProvider);
  return box
      .watch()
      .startWith(BoxEvent(box.name, null, false))
      .map((_) => box.values.toList());
}