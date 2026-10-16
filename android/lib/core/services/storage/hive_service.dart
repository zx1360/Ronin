import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:torrid/core/services/debug/logging_service.dart';
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
// gallery库
// comic漫画
import 'package:torrid/features/others/comic/models/comic_preference.dart';
import 'package:torrid/features/chat/models/chat_models.dart';
import 'package:torrid/features/chat/models/review_models.dart';

// 全局注册所有Adapter和常用Box, 非常用Box到特定页面再打开
class HiveService {
  // 常用Box名
  // booklet打卡
  static const String styleBoxName = 'styles';
  static const String recordBoxName = 'records';
  // essay随笔
  static const String yearSummaryBoxName = 'yearSummaries';
  static const String labelBoxName = 'labels';
  static const String essayBoxName = 'essays';
  static const String essayDraftBoxName = 'essayDrafts';
  // chat对话(仅本地)
  static const String chatBoxName = 'chatConversations';
  // 近期回顾(仅本地: 预设镜像 + 生成结果)
  static const String reviewPresetBoxName = 'reviewPresets';
  static const String reviewHistoryBoxName = 'reviewHistory';
  // 非常用
  // comic漫画
  static const String comicPrefBoxName = "comicPreference";
  static const String comicBoxName = "comicInfo";
  static const String chapterBoxName = "chapterInfo";

  static void _register<Value>(TypeAdapter<Value> adapter) {
    if (!Hive.isAdapterRegistered(adapter.typeId)) {
      Hive.registerAdapter(adapter);
    }
  }

  static Future<Box<Value>> _open<Value>(String name) {
    final result = Completer<Box<Value>>();
    // Hive 2 的打开失败还会向内部 completer 重复报告同一异常。
    runZonedGuarded(() async {
      try {
        result.complete(await Hive.openBox<Value>(name));
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    }, (error, stack) => AppLogger().error('Hive 打开失败: $name', error, stack));
    return result.future;
  }

  // 常用Box
  static Future<void> init() async {
    // 注册适配器
    // 通用
    _register(MoodTypeAdapter());
    // booklet打卡
    _register(StyleAdapter());
    _register(TaskAdapter());
    _register(RecordAdapter());
    // essay随笔
    _register(MonthSummaryAdapter());
    _register(YearSummaryAdapter());
    _register(LabelAdapter());
    _register(EssayAdapter());
    _register(MessageAdapter());

    // comic漫画
    _register(ComicInfoAdapter());
    _register(ChapterInfoAdapter());
    _register(ComicPreferenceAdapter());

    // chat对话
    _register(ChatConversationAdapter());
    _register(ChatMessageAdapter());
    _register(ChatAttachmentAdapter());

    // 近期回顾
    _register(ReviewPresetAdapter());
    _register(ReviewRecordAdapter());

    // 打开(创建)箱
    await Future.wait([
      _open<String>('userDataSync'),
      _open<Style>(styleBoxName),
      _open<Record>(recordBoxName),
      _open<YearSummary>(yearSummaryBoxName),
      _open<Label>(labelBoxName),
      _open<Essay>(essayBoxName),
      _open<String>(essayDraftBoxName),
      _open<ChatConversation>(chatBoxName),
      _open<ReviewPreset>(reviewPresetBoxName),
      _open<ReviewRecord>(reviewHistoryBoxName),
    ]);
    final labels = Hive.box<Label>(labelBoxName);
    if (!labels.values.any((label) => label.isHiddenRoot)) {
      await labels.put(Label.hiddenId, Label.hidden());
    }
  }

  // 非常用Box
  static Future<void> initComic() async {
    if (!Hive.isBoxOpen(comicPrefBoxName)) {
      await _open<ComicPreference>(comicPrefBoxName);
    }
    if (!Hive.isBoxOpen(comicBoxName)) {
      await _open<ComicInfo>(comicBoxName);
    }
    if (!Hive.isBoxOpen(chapterBoxName)) {
      await _open<ChapterInfo>(chapterBoxName);
    }
  }
}
