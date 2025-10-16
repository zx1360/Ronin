// 标签列表提供者
import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/transformers.dart';
import 'package:torrid/features/essay/models/essay.dart';
import 'package:torrid/features/essay/models/label.dart';
import 'package:torrid/features/essay/providers/box_provider.dart';

part 'status_provider.g.dart';

// ----Stream响应每次的box内容修改, List暴露简单的同步数据.
// essays数据
@riverpod
Stream<List<Essay>> essayStream(EssayStreamRef ref) {
  final box = ref.read(essayBoxProvider);
  return box
      .watch()
      .startWith(BoxEvent(box.name, null, false))
      .map((_) => box.values.toList());
}

@riverpod
List<Essay> essays(EssaysRef ref) {
  final asyncVal = ref.watch(essayStreamProvider);
  if (asyncVal.hasError) {
    throw asyncVal.error!;
  }
  final idMaps = ref.watch(idMapProvider);
  final essays = asyncVal.asData?.value ?? [];
  if(essays.isNotEmpty){
    for (var essay in essays) {
      for (int i = 0; i < essay.labels.length; i++) {
          essay.labels[i] = idMaps[essay.labels[i]]!;
        }
    }
  }
  return essays;
}

// labels数据
@riverpod
Stream<List<Label>> labelStream(LabelStreamRef ref) {
  final box = ref.read(labelBoxProvider);
  return box
      .watch()
      .startWith(BoxEvent(box.name, null, false))
      .map((_) => box.values.toList());
}

@riverpod
List<Label> labels(LabelsRef ref) {
  final asyncVal = ref.watch(labelStreamProvider);
  if (asyncVal.hasError) {
    throw asyncVal.error!;
  }
  return asyncVal.asData?.value ?? [];
}

@riverpod
Map<String, String> idMap(IdMapRef ref) {
  final allLabels = ref.watch(labelsProvider);
  return {for (final label in allLabels) label.id: label.name};
}
