import 'package:hive_flutter/hive_flutter.dart';
import 'package:torrid/features/booklet/models/style.dart';
import 'package:torrid/features/booklet/models/record.dart';

import 'package:torrid/features/booklet/models/task.dart';

// TODO: 也许之后跳转每一个独立板块中间都用过渡屏转场, 并在其中初始化? (再说吧, 复杂度上来耗时久了再改)
class BookletHiveService {
  static const String styleBoxName = 'styles';
  static const String recordBoxName = 'records';

  static Future<void> init() async {
    Hive.registerAdapter(StyleAdapter());
    Hive.registerAdapter(TaskAdapter());
    Hive.registerAdapter(RecordAdapter());

    await Hive.openBox<Style>(styleBoxName);
    await Hive.openBox<Record>(recordBoxName);
  }

  static Future<void> close() async {
    await Hive.close();
  }
}
