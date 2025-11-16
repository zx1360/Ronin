import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torrid/services/storage/hive_service.dart';
import 'package:torrid/services/storage/prefs_service.dart';
import 'package:torrid/features/others/comic/models/comic_preference.dart';

// 漫画进度Provider（全局唯一）
final comicPreferenceProvider =
    StateNotifierProvider<
      ComicPreferenceNotifier,
      Map<String, ComicPreference>
    >((ref) => ComicPreferenceNotifier());

// 最近阅读漫画名Provider
final latestReadComicProvider = FutureProvider<String?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('latest_read_comic');
});

class ComicPreferenceNotifier
    extends StateNotifier<Map<String, ComicPreference>> {
  late final Box<ComicPreference> _progressBox;

  ComicPreferenceNotifier() : super({}) {
    _progressBox = Hive.box<ComicPreference>(HiveService.comicPrefBoxName);
    _loadProgressFromHive();
  }

  /// 根据漫画名更新阅读进度（自动同步最近阅读记录）
  /// [comicName]：漫画名（唯一key）
  /// [chapterIndex]：当前章节索引
  /// [pageIndex]：当前页面索引
  void updateProgress({
    required String comicName,
    required int chapterIndex,
    required int pageIndex,
  }) {
    if (chapterIndex < 0 || pageIndex < 0) return;

    // 1. 更新内存与Hive进度
    // TODO:
    final newProgress = ComicPreference(
      comicId: "TODO",
      chapterIndex: chapterIndex,
      pageIndex: pageIndex,
    );
    state = {...state, comicName: newProgress};
    _progressBox.put(comicName, newProgress);

    // 2. 同步最近阅读到SharedPreferences
    _updateLatestReadComic(comicName);
  }

  /// 根据漫画名获取阅读进度
  /// 返回null表示无历史进度
  ComicPreference? getProgress(String comicName) {
    return state[comicName] ?? _progressBox.get(comicName);
  }

  /// 从Hive加载历史进度到内存
  void _loadProgressFromHive() {
    final progressMap = <String, ComicPreference>{};
    try {
      for (final key in _progressBox.keys) {
        if (key is String) {
          final progress = _progressBox.get(key);
          if (progress != null) progressMap[key] = progress;
        }
      }
      state = progressMap;
    } catch (e) {
      if (kDebugMode) print('加载进度失败: $e');
      state = {};
    }
  }

  /// 更新最近阅读漫画记录到SharedPreferences
  Future<void> _updateLatestReadComic(String comicName) async {
    try {
      final prefs = PrefsService().prefs;
      await prefs.setString('latest_read_comic', comicName);
    } catch (e) {
      if (kDebugMode) print('更新最近阅读失败: $e');
    }
  }

  @override
  void dispose() {
    _progressBox.close();
    super.dispose();
  }
}
