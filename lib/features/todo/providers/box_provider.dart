import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:torrid/features/todo/models/task_list.dart';
import 'package:torrid/services/storage/hive_service.dart';

part 'box_provider.g.dart';

@riverpod
Box<TaskList> taskListBox(TaskListBoxRef ref) {
  return Hive.box(HiveService.taskListsBoxName);
}

@riverpod
Stream<List<TaskList>> taskListStream(TaskListStreamRef ref) async* {
  final box = ref.read(taskListBoxProvider);
  yield box.values.toList();
  await for(final event in box.watch()){
    if(event.deleted||event.value!=null){
      yield box.values.toList();
    }
  }
}
