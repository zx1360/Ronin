import 'package:hive_flutter/hive_flutter.dart';
import 'package:torrid/core/models/message.dart';
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
import 'package:torrid/features/others/tuntun/models/info.dart';
import 'package:torrid/features/others/tuntun/models/status.dart';
import 'package:torrid/features/todo/models/task_list.dart';
// tuntun藏品
// comic漫画
import 'package:torrid/features/others/comic/models/comic_preference.dart';
import 'package:torrid/features/todo/models/todo_task.dart';
// changya 随机唱歌音频
import 'package:torrid/features/read/models/changya_user.dart';
import 'package:torrid/features/read/models/changya_song.dart';
import 'package:torrid/features/read/models/changya_audio.dart';
import 'package:torrid/features/read/models/changya_record.dart';

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
  static const String comicPrefBoxName = "comicPreference";
  static const String comicBoxName = "comicInfo";
  static const String chapterBoxName = "chapterInfo";
  // changya 随机唱歌音频
  static const String changyaBoxName = 'changyaRecords';

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
    Hive.registerAdapter(ComicInfoAdapter());
    Hive.registerAdapter(ChapterInfoAdapter());
    Hive.registerAdapter(ComicPreferenceAdapter());
    // changya
    Hive.registerAdapter(ChangyaUserAdapter());
    Hive.registerAdapter(ChangyaSongAdapter());
    Hive.registerAdapter(ChangyaAudioAdapter());
    Hive.registerAdapter(ChangyaRecordAdapter());

    // 打开(创建)箱
    await Hive.openBox<Style>(styleBoxName);
    await Hive.openBox<Record>(recordBoxName);

    await Hive.openBox<YearSummary>(yearSummaryBoxName);
    await Hive.openBox<Label>(labelBoxName);
    await Hive.openBox<Essay>(essayBoxName);

    await Hive.openBox<TaskList>(taskListsBoxName);
    await Hive.openBox<ChangyaRecord>(changyaBoxName);
  }

  // ----非常用Box----
  static Future<void> initTuntun() async {
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
