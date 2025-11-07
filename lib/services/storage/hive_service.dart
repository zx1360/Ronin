import 'package:hive_flutter/hive_flutter.dart';
// booklet打卡
import 'package:torrid/features/booklet/models/style.dart';
import 'package:torrid/features/booklet/models/record.dart';
import 'package:torrid/features/booklet/models/task.dart';
// essay随笔
import 'package:torrid/features/essay/models/essay.dart';
import 'package:torrid/features/essay/models/label.dart';
import 'package:torrid/features/essay/models/year_summary.dart';
import 'package:torrid/features/todo/models/todo_task.dart';
import 'package:torrid/features/todo/models/task_list.dart';
import 'package:torrid/shared/models/message.dart';
// tuntun藏品
import 'package:torrid/features/others/tuntun/models/info.dart';
import 'package:torrid/features/others/tuntun/models/status.dart';
// comic漫画
import 'package:torrid/features/others/comic/models/comic_progress.dart';

// 全局注册所有Adapter和常用Box, 非常用Box到特定页面再打开
class HiveService {
  // ----常用Box名
  // booklet打卡
  static const String styleBoxName = 'styles';
  static const String recordBoxName = 'records';
  // essay随笔
  static const String yearSummaryBoxName = 'yearSummaries';
  static const String labelBoxName = 'labels';
  static const String essayBoxName = 'essays';
  // todo待办
  static const String taskListsBoxName = 'taskLists';
  // ----非常用
  // tuntun藏品
  static const String infoBoxName = "mediaInfo";
  static const String statusBoxName = "mediaStatus";
  // comic漫画
  static const String progressBoxName = "comicProgress";

  // ----常用Box----
  static Future<void> init() async {
    // ----注册适配器
    // booklet打卡
    Hive.registerAdapter(StyleAdapter());
    Hive.registerAdapter(TaskAdapter());
    Hive.registerAdapter(RecordAdapter());
    // essay随笔
    Hive.registerAdapter(MonthSummaryAdapter());
    Hive.registerAdapter(YearSummaryAdapter());
    Hive.registerAdapter(LabelAdapter());
    Hive.registerAdapter(EssayAdapter());
    Hive.registerAdapter(MessageAdapter());
    // todo待办
    Hive.registerAdapter(PriorityAdapter());
    Hive.registerAdapter(TodoTaskAdapter());
    Hive.registerAdapter(TaskListAdapter());
    // tuntun藏品
    Hive.registerAdapter(InfoAdapter());
    Hive.registerAdapter(StatusAdapter());
    // comic漫画
    Hive.registerAdapter(ComicProgressAdapter());

    // 打开(创建)箱
    await Hive.openBox<Style>(styleBoxName);
    await Hive.openBox<Record>(recordBoxName);

    await Hive.openBox<YearSummary>(yearSummaryBoxName);
    await Hive.openBox<Label>(labelBoxName);
    await Hive.openBox<Essay>(essayBoxName);

    await Hive.openBox<TaskList>(taskListsBoxName);
  }

  // ----非常用Box----
  static Future<void> initTuntun() async {
    if (!Hive.isBoxOpen(infoBoxName)) {
      await Hive.openBox<Info>(infoBoxName);
    }
    if (!Hive.isBoxOpen(statusBoxName)) {
      await Hive.openBox<Status>(statusBoxName);
    }

    // TODO: 之前想的是用shared_preferences存储元数据比如漫画信息, 现在感觉用Hive的List<Map>或Map格式也行.
  }

  static Future<void> initComic() async {
    if (!Hive.isBoxOpen(progressBoxName)) {
      await Hive.openBox<ComicProgress>(progressBoxName);
    }
  }

  //
}
