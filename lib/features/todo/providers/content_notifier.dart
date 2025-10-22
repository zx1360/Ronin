import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/todo/models/task_list.dart';

part 'content_notifier.g.dart';

@riverpod
class ContentService extends _$ContentService {
  @override
  TaskList? build() {
    return null;
  }

  void switchList({required TaskList list}) {
    state = list;
  }
}
