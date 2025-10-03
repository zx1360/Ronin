import 'dart:convert';
import 'dart:math';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:torrid/features/booklet/models/style.dart';
import 'package:torrid/features/booklet/models/task.dart';
import 'package:torrid/features/booklet/models/record.dart';

import 'package:torrid/core/services/io/io_service.dart';
import 'package:torrid/core/services/storage/prefs_service.dart';

import 'package:torrid/shared/utils/util.dart';

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

  static Box<Style> get _styleBox => Hive.box(styleBoxName);
  static Box<Record> get _recordBox => Hive.box(recordBoxName);

  // 辅助函数：判断两个日期是否为同一天（忽略时间）
  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // 1. 获取startDate最大(最新)的Style对象，无数据则返回null
  static Style? getLatestStyle() {
    final styles = _styleBox.values.toList();
    if (styles.isEmpty) return null;

    return styles.reduce((a, b) => a.startDate.isAfter(b.startDate) ? a : b);
  }

  // 2. 返回与传入styleId关联的今日Record，无则返回null
  static Record? getTodayRecordByStyleId(String styleId) {
    // 获取今天的日期（仅包含年月日）
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // 筛选出匹配styleId且日期为今天的记录
    final todayRecords = _recordBox.values
        .where(
          (record) =>
              record.styleId == styleId && _isSameDay(record.date, todayDate),
        )
        .toList();

    // 返回今日记录（如无则返回null）
    return todayRecords.isNotEmpty ? todayRecords.first : null;
  }

  /// 根据StyleId筛选记录（按日期倒序排列）
  /// [styleId]：样式ID
  static List<Record> getRecordsByStyleId(String styleId) {
    return BookletHiveService.getAllRecords()
        .where((r) => r.styleId == styleId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  // 3. 更新Record, 并更新对应的style信息.
  static Future<void> updateRecord({
    required String styleId,
    required Record record,
  }) async {
    _recordBox.put(record.id, record);
    refreshOne(styleId);
  }

  // 5. 获取所有Style数据
  static List<Style> getAllStyles() {
    return _styleBox.values.toList();
  }

  // 6. 获取所有Record数据
  static List<Record> getAllRecords() {
    return _recordBox.values.toList();
  }

  // 7. 删除如果最近的样式是今天开始的, 删去.(新建样式时调用)
  static Future<void> deleteTodayStyle() async {
    Style? latestStyle = getLatestStyle();
    if (latestStyle == null) return;
    while (Util.isSameDay(getTodayDate(), latestStyle!.startDate)) {
      _styleBox.delete(latestStyle.id);
      latestStyle = getLatestStyle();
      if (latestStyle == null) return;
    }
  }

  // 8. 根据styleId获取style
  static Style? getStyleById(String id) {
    return _styleBox.get(id);
  }

  // ####### 全部style刷新信息;
  static Future<void> refreshAll() async {
    final allStyles = _styleBox.values.toList();
    for (final style in allStyles) {
      await refreshOne(style.id);
    }
  }

  // ####### 根据styleId刷新单个Style的统计信息
  static Future<void> refreshOne(String styleId) async {
    // 获取对应的Style
    final styles = _styleBox.values.where((s) => s.id == styleId).toList();
    if (styles.isEmpty) return;
    final style = styles.first;

    // 获取该Style关联的所有记录
    final relatedRecords = _recordBox.values
        .where((record) => record.styleId == styleId)
        .toList();

    // 计算各项统计值
    final validCheckIn = relatedRecords.length;
    final fullyDoneCount = _calculateFullyDone(relatedRecords);
    final longestStreak = _calculateLongestStreak(relatedRecords);
    final longestFullyStreak = _calculateLongestFullyStreak(relatedRecords);

    // 创建更新后的Style对象（需要Style类支持id传入）
    final updatedStyle = Style(
      id: style.id,
      startDate: style.startDate,
      validCheckIn: validCheckIn,
      fullyDone: fullyDoneCount,
      longestStreak: longestStreak,
      longestFullyStreak: longestFullyStreak,
      tasks: style.tasks,
    );

    // 保存更新后的Style
    await _styleBox.put(style.id, updatedStyle);
  }

  /// 计算完全完成的记录数量
  static int _calculateFullyDone(List<Record> records) {
    return records.where((record) {
      // 检查所有任务是否都已完成
      if (record.taskCompletion.isEmpty) return false;
      return record.taskCompletion.values.every((isCompleted) => isCompleted);
    }).length;
  }

  /// 计算最长连续打卡天数
  static int _calculateLongestStreak(List<Record> records) {
    if (records.isEmpty) return 0;

    // 提取并排序所有不重复的日期
    final uniqueDates =
        records
            .map((r) => DateTime(r.date.year, r.date.month, r.date.day))
            .toSet()
            .toList()
          ..sort();

    return _getLongestConsecutiveDays(uniqueDates);
  }

  /// 计算最长连续完全完成天数
  static int _calculateLongestFullyStreak(List<Record> records) {
    if (records.isEmpty) return 0;

    // 筛选出完全完成的记录并提取不重复日期
    final fullyDoneDates =
        records
            .where((record) => record.taskCompletion.values.every((v) => v))
            .map((r) => DateTime(r.date.year, r.date.month, r.date.day))
            .toSet()
            .toList()
          ..sort();

    return _getLongestConsecutiveDays(fullyDoneDates);
  }

  /// 计算日期列表中最长连续天数
  static int _getLongestConsecutiveDays(List<DateTime> sortedDates) {
    if (sortedDates.isEmpty) return 0;

    int maxStreak = 1;
    int currentStreak = 1;

    for (int i = 1; i < sortedDates.length; i++) {
      final dayDiff = sortedDates[i].difference(sortedDates[i - 1]).inDays;

      if (dayDiff == 1) {
        // 连续日期，增加当前 streak
        currentStreak++;
        maxStreak = max(maxStreak, currentStreak);
      } else if (dayDiff != 0) {
        // 非连续且非同一天，重置当前 streak
        currentStreak = 1;
      }
      // 同一天不做处理
    }

    return maxStreak;
  }

  // # 根据传入的数据覆盖本地的booklet存储数据.
  // TODO: 由于从sqlite3转到这里, 如果id格式不一样需要转的时候要保持数据对应, 以后格式完全一样后就删掉这部分逻辑.
  static Future<void> syncData(dynamic json) async {
    try {
      // 保存信息数据
      await _styleBox.clear();
      await _recordBox.clear();
      final jsonStyles = json['styles'];
      // 记录新旧styleId的对应关系
      Map<String, String> styleIdMap = {};
      // 记录新旧任务id的对应关系,
      Map<String, String> taskIdMap = {};
      for (dynamic style in jsonStyles) {
        Style style_ = Style.fromJson(style);
        await _styleBox.put(style_.id, style_);
        styleIdMap.addAll({style['id']: style_.id});

        for (int i = 0; i < style_.tasks.length; i++) {
          taskIdMap.addAll({
            style['tasks'][i]['id'] as String: style_.tasks[i].id,
          });
        }
      }

      final jsonRecords = json['records'];
      for (dynamic record in jsonRecords) {
        Record record_ = Record.noId(
          styleId: styleIdMap[record['styleId']]!,
          date: DateTime.parse(record['date']),
          message: record['message'] ?? "",
          taskCompletion: (record['taskCompletion']! as Map).map((key, value) {
            return MapEntry(taskIdMap[key]!, value);
          }),
        );
        await _recordBox.put(record_.id, record_);
      }

      // 一并同步对应的task图片文件
      // TODO: 检查完全按预期结果验证.
      List<String> urls = [];
      final prefs = await PrefsService.prefs;
      final url = prefs.getString("PC_IP");
      _styleBox.values.toList().forEach((style) {
        style.tasks
            .where((task) => task.image.isNotEmpty && task.image != '')
            .forEach((task) {
              urls.add("http://$url:4215/static/${task.image}");
            });
      });
      if (urls.isNotEmpty) {
        await IoService.saveFromUrls(urls, "img_storage/booklet/zx.1360");
      }
    } catch (e) {
      throw Exception("Booklet同步出错咯 $e");
    }
  }

  // # 打包本地Booklet数据
  static Map<String, dynamic> packUp() {
    try {
      List styles = BookletHiveService.getAllStyles().toList()
        ..sort((a, b) => b.startDate.compareTo(a.startDate));
      styles = styles.map((item) => item.toJson()).toList();

      List records = BookletHiveService.getAllRecords().toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      records = records.map((item) => item.toJson()).toList();

      return {"jsonData": jsonEncode({"styles": styles, "records": records})};
    } catch (err) {
      throw Exception(err);
    }
  }

  // 一并上传task图片
  static List<String> getImgsPath() {
    List<String> urls = [];
    _styleBox.values.toList().forEach((style) {
      style.tasks
          .where((task) => task.image.isNotEmpty && task.image != '')
          .forEach((task) {
            final relativePath = task.image.startsWith("/")
                ? task.image.replaceFirst("/", "")
                : task.image;
            urls.add(relativePath);
          });
    });
    return urls;
  }
}
