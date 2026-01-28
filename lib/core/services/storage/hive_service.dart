import 'package:hive_flutter/hive_flutter.dart';
import 'package:torrid/core/models/message.dart';
import 'package:torrid/core/models/mood.dart';
// booklet打卡
import 'package:torrid/features/booklet/models/style.dart';
import 'package:torrid/features/booklet/models/record.dart';
import 'package:torrid/features/booklet/models/task.dart';
// essay随笔
import 'package:torrid/features/essay/models/essay.dart';
import 'package:torrid/features/essay/models/label.dart';
import 'package:torrid/features/essay/models/year_summary.dart';
import 'package:torrid/features/others/comic/models/chapter_info.dart';
import 'package:torrid/features/others/comic/models/comic_info.dart';
import 'package:torrid/features/todo/models/task_list.dart';
// gallery库
// comic漫画
import 'package:torrid/features/others/comic/models/comic_preference.dart';
import 'package:torrid/features/todo/models/todo_task.dart';
// changya 随机唱歌音频
import 'package:torrid/features/read/models/changya/changya_user.dart';
import 'package:torrid/features/read/models/changya/changya_song.dart';
import 'package:torrid/features/read/models/changya/changya_audio.dart';
import 'package:torrid/features/read/models/changya/changya_record.dart';
// lathe倒计时
import 'package:torrid/features/others/lathe/models/countdown_timer_model.dart';

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
  static const String todoTasksBoxName = 'todoTasks';
  // lathe倒计时
  static const String countdownTimerBoxName = 'countdownTimers';
  // ----非常用
  // gallery库
  static const String infoBoxName = "mediaInfo";
  static const String statusBoxName = "mediaStatus";
  // comic漫画
  static const String comicPrefBoxName = "comicPreference";
  static const String comicBoxName = "comicInfo";
  static const String chapterBoxName = "chapterInfo";
  // changya 随机唱歌音频
  static const String changyaBoxName = 'changyaRecords';

  // ----常用Box----
  static Future<void> init() async {
    // ----注册适配器
    // 通用
    Hive.registerAdapter(MoodTypeAdapter());
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
    Hive.registerAdapter(RepeatTypeAdapter());
    Hive.registerAdapter(TodoStepAdapter());
    Hive.registerAdapter(TodoTaskAdapter());
    Hive.registerAdapter(ListThemeColorAdapter());
    Hive.registerAdapter(TaskListAdapter());
    // gallery库
    
    // comic漫画
    Hive.registerAdapter(ComicInfoAdapter());
    Hive.registerAdapter(ChapterInfoAdapter());
    Hive.registerAdapter(ComicPreferenceAdapter());
    // changya
    Hive.registerAdapter(ChangyaUserAdapter());
    Hive.registerAdapter(ChangyaSongAdapter());
    Hive.registerAdapter(ChangyaAudioAdapter());
    Hive.registerAdapter(ChangyaRecordAdapter());
    // lathe倒计时
    Hive.registerAdapter(CountdownTimerStatusAdapter());
    Hive.registerAdapter(CountdownTimerModelAdapter());

    // 打开(创建)箱
    await Hive.openBox<Style>(styleBoxName);
    await Hive.openBox<Record>(recordBoxName);

    await Hive.openBox<YearSummary>(yearSummaryBoxName);
    await Hive.openBox<Label>(labelBoxName);
    await Hive.openBox<Essay>(essayBoxName);

    // todo 模块
    await Hive.openBox<TaskList>(taskListsBoxName);
    await Hive.openBox<TodoTask>(todoTasksBoxName);
    
    await Hive.openBox<ChangyaRecord>(changyaBoxName);
    await Hive.openBox<CountdownTimerModel>(countdownTimerBoxName);
  }

  // ----非常用Box----
  static Future<void> initGallery() async {
    // if (!Hive.isBoxOpen(infoBoxName)) {
    //   await Hive.openBox<Info>(infoBoxName);
    // }
    // if (!Hive.isBoxOpen(statusBoxName)) {
    //   await Hive.openBox<Status>(statusBoxName);
    // }
  }

  static Future<void> initComic() async {
    if (!Hive.isBoxOpen(comicPrefBoxName)) {
      await Hive.openBox<ComicPreference>(comicPrefBoxName);
    }
    if (!Hive.isBoxOpen(comicBoxName)) {
      await Hive.openBox<ComicInfo>(comicBoxName);
    }
    if (!Hive.isBoxOpen(chapterBoxName)) {
      await Hive.openBox<ChapterInfo>(chapterBoxName);
    }
  }
}
