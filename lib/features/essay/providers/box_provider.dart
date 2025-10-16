// Hive 盒子提供者
import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/essay/models/essay.dart';
import 'package:torrid/features/essay/models/label.dart';

part 'box_provider.g.dart';

@riverpod
Box<Essay> essayBox(EssayBoxRef ref){
  return Hive.box<Essay>('essays');
}

@riverpod
Box<Label> labelBox(LabelBoxRef ref){
  return Hive.box<Label>('labels');
}