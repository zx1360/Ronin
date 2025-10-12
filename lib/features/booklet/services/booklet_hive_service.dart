import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:torrid/features/booklet/models/style.dart';
import 'package:torrid/features/booklet/models/record.dart';

import 'package:torrid/core/services/io/io_service.dart';
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

  static Box<Style> get _styleBox => Hive.box(styleBoxName);
  static Box<Record> get _recordBox => Hive.box(recordBoxName);

  // 获取所有Style数据
  static List<Style> getAllStyles() {
    return _styleBox.values.toList();
  }

  // 获取所有Record数据
  static List<Record> getAllRecords() {
    return _recordBox.values.toList();
  }

  // # 根据传入的数据覆盖本地的booklet存储数据.
  static Future<void> syncData(dynamic json) async {
    await _styleBox.clear();
    await _recordBox.clear();

    // 存储json数据到Hive.
    List jsonStyles = json['styles'];
    List jsonRecords = json['records'];
    for (dynamic style in jsonStyles) {
      Style style_ = Style.fromJson(style);
      await _styleBox.put(style_.id, style_);
    }
    for (dynamic record in jsonRecords) {
      Record record_ = Record.fromJson(record);
      await _recordBox.put(record_.id, record_);
    }
    // 将其中的task图片文件同时保存到本地.
    final List<String> urls = [];
    for (var style in _styleBox.values) {
      style.tasks.where((task) => task.image.isNotEmpty).forEach((task) {
        urls.add(task.image);
      });
    }
    if (urls.isNotEmpty) {
      await IoService.saveFromRelativeUrls(urls, "img_storage/booklet");
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

      return {
        "jsonData": jsonEncode({"styles": styles, "records": records}),
      };
    } catch (err) {
      throw Exception(err);
    }
  }

  // 打包task图片路径.
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
