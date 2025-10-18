import 'dart:convert';

import 'package:hive_flutter/adapters.dart';
import 'package:torrid/services/io/io_service.dart';
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

  // 定义getter方法.
  static Box<YearSummary> get _yearSummaryBox => Hive.box(yearSummaryBoxName);
  static Box<Essay> get _essayBox => Hive.box(essayBoxName);
  static Box<Label> get _labelBox => Hive.box(labelBoxName);

  static List<YearSummary> get allYearSummaries =>
      _yearSummaryBox.values.toList();
  static List<Essay> get allEssays => _essayBox.values.toList();
  static List<Label> get allLabels => _labelBox.values.toList();

  // ####### 同步数据至本地
  // TODO: 数据格式完全一样之后删去相关逻辑.
  static Future<void> syncData(dynamic json) async {
    try {
      await _yearSummaryBox.clear();
      await _labelBox.clear();
      await _essayBox.clear();

      // 年度(月度)信息
      for (Map<String, dynamic> yearSummary
          in (json['year_summaries'] as List)) {
        await _yearSummaryBox.put(
          yearSummary['year'],
          YearSummary.fromJson(yearSummary),
        );
      }
      final Map<String, String> labelIdMap = {};
      // 标签信息
      for (Map<String, dynamic> label in (json['labels'] as List)) {
        final label_ = Label.fromJson(label);
        labelIdMap.addAll({label['id']: label_.id});
        await _labelBox.put(label_.id, label_);
      }
      // 随笔内容
      for (Map<String, dynamic> essay in (json['essays'] as List)) {
        var essay_ = Essay.fromJson(essay);
        essay_ = essay_.copyWith(
          labels: essay_.labels.map((label) => labelIdMap[label]!).toList(),
        );
        await _essayBox.put(essay_.id, essay_);
      }
      // 一并保存图片文件
      List<String> urls = [];
      _essayBox.values.where((essay) => essay.imgs.isNotEmpty).toList().forEach(
        (essay) {
          for (var img in essay.imgs) {
            urls.add(img);
          }
        },
      );
      if (urls.isNotEmpty) {
        await IoService.saveFromRelativeUrls(urls, "img_storage/essay");
      }
    } catch (err) {
      throw Exception("同步essay出错: $err");
    }
  }

  // 打包essay本地数据
  static Map<String, dynamic> packUp() {
    final yearSummaries = allYearSummaries
        .map((item) => item.toJson())
        .toList();
    final labels = allLabels.map((item) => item.toJson()).toList();
    final essays = allEssays.map((item) => item.toJson()).toList();
    try {
      return {
        "jsonData": jsonEncode({
          "year_summaries": yearSummaries,
          "labels": labels,
          "essays": essays,
        }),
      };
    } catch (err) {
      throw Exception("打包出错:$err");
    }
  }

  // 上传相关图片
  static List<String> getImgsPath() {
    List<String> urls = [];
    _essayBox.values.toList().forEach((essay) {
      for (var img in essay.imgs) {
        final relativePath = img.startsWith("/")
            ? img.replaceFirst("/", "")
            : img;
        urls.add(relativePath);
      }
    });
    return urls;
  }
}
