import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/todo/models/task_list.dart';
import 'package:torrid/features/todo/providers/notifier_provider.dart';

part 'content_provider.g.dart';

@riverpod
class Content extends _$Content {
  @override
  TaskList? build() {
    // 通过Future()延后一帧.
    Future(() async {
      initDefault();
    });
    return null;
  }

  Future<void> initDefault() async {
    await ref.read(todoServiceProvider.notifier).initDefault();
    switchList(
      ref
          .read(todoServiceProvider)
          .taskListBox
          .values
          // .where((l) => l.name == '我的一天')
          .where((l) => l.name == '任务')
          .first,
    );
  }

  void switchList(TaskList list) {
    state = list;
  }
}
