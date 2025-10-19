import 'package:hive_flutter/adapters.dart';
import 'package:torrid/features/essay/models/essay.dart';
import 'package:torrid/features/essay/models/label.dart';
import 'package:torrid/features/essay/models/year_summary.dart';
import 'package:torrid/shared/models/message.dart';

class EssayHiveService {
  // 表名
  static const String yearSummaryBoxName = 'year_summaries';
  static const String labelBoxName = 'labels';
  static const String essayBoxName = 'essays';

  // 初始化Hive
  static Future<void> init() async {
    // 注册适配器
    Hive.registerAdapter(MonthSummaryAdapter());
    Hive.registerAdapter(YearSummaryAdapter());
    Hive.registerAdapter(LabelAdapter());
    Hive.registerAdapter(EssayAdapter());

    Hive.registerAdapter(MessageAdapter());

    // 打开(创建)箱
    await Hive.openBox<YearSummary>(yearSummaryBoxName);
    await Hive.openBox<Label>(labelBoxName);
    await Hive.openBox<Essay>(essayBoxName);
  }

  // 关闭箱
  static Future<void> close() async {
    await Hive.close();
  }
}
