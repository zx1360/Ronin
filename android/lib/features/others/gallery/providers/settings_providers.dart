import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/core/services/storage/prefs_service.dart';

part 'settings_providers.g.dart';

// ============ 设置项 Providers (SharedPreferences) ============

/// Gallery 设置常量
class GalleryPrefsKeys {
  static const String modifiedCount = 'gallery_modified_count';
  static const String currentIndex = 'gallery_current_index';
  static const String gridColumnCount = 'gallery_grid_columns';
  static const String previewWindowEnabled = 'gallery_preview_window_enabled';
  // 下载筛选设置
  static const String downloadMimeFilter = 'gallery_download_mime_filter';
  static const String downloadSortBy = 'gallery_download_sort_by';
  static const String downloadSortOrder = 'gallery_download_sort_order';
  static const String downloadYear = 'gallery_download_year';
  static const String downloadMonth = 'gallery_download_month';
  static const String downloadDay = 'gallery_download_day';
  static const String downloadSecondarySort = 'gallery_download_secondary_sort';
}

/// modified_count - 记录最后一次操作的媒体文件在队列中的位置
@Riverpod(keepAlive: true)
class GalleryModifiedCount extends _$GalleryModifiedCount {
  @override
  int build() {
    final prefs = PrefsService().prefs;
    return prefs.getInt(GalleryPrefsKeys.modifiedCount) ?? 0;
  }

  Future<void> update(int value) async {
    final prefs = PrefsService().prefs;
    await prefs.setInt(GalleryPrefsKeys.modifiedCount, value);
    state = value;
  }

  /// 重置为 0
  Future<void> reset() async {
    await update(0);
  }
}

/// 当前浏览位置索引
@Riverpod(keepAlive: true)
class GalleryCurrentIndex extends _$GalleryCurrentIndex {
  @override
  int build() {
    final prefs = PrefsService().prefs;
    return prefs.getInt(GalleryPrefsKeys.currentIndex) ?? 0;
  }

  Future<void> update(int value) async {
    final prefs = PrefsService().prefs;
    await prefs.setInt(GalleryPrefsKeys.currentIndex, value);
    state = value;
  }
}

/// 网格视图每行数量 (3, 4, 8, 16)
@Riverpod(keepAlive: true)
class GalleryGridColumns extends _$GalleryGridColumns {
  static const List<int> allowedValues = [3, 4, 8, 16];

  @override
  int build() {
    final prefs = PrefsService().prefs;
    return prefs.getInt(GalleryPrefsKeys.gridColumnCount) ?? 4;
  }

  Future<void> zoomIn() async {
    final currentIdx = allowedValues.indexOf(state);
    if (currentIdx > 0) {
      await _update(allowedValues[currentIdx - 1]);
    }
  }

  Future<void> zoomOut() async {
    final currentIdx = allowedValues.indexOf(state);
    if (currentIdx < allowedValues.length - 1) {
      await _update(allowedValues[currentIdx + 1]);
    }
  }

  Future<void> _update(int value) async {
    final prefs = PrefsService().prefs;
    await prefs.setInt(GalleryPrefsKeys.gridColumnCount, value);
    state = value;
  }
}

/// 预览小窗开关设置（默认开启）
@Riverpod(keepAlive: true)
class GalleryPreviewWindowEnabled extends _$GalleryPreviewWindowEnabled {
  @override
  bool build() {
    final prefs = PrefsService().prefs;
    return prefs.getBool(GalleryPrefsKeys.previewWindowEnabled) ?? true;
  }

  Future<void> toggle() async {
    final prefs = PrefsService().prefs;
    final newValue = !state;
    await prefs.setBool(GalleryPrefsKeys.previewWindowEnabled, newValue);
    state = newValue;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = PrefsService().prefs;
    await prefs.setBool(GalleryPrefsKeys.previewWindowEnabled, enabled);
    state = enabled;
  }
}

/// 下载 MIME 类型筛选（空=全部, image, video）
@Riverpod(keepAlive: true)
class GalleryDownloadMimeFilter extends _$GalleryDownloadMimeFilter {
  @override
  String build() {
    final prefs = PrefsService().prefs;
    return prefs.getString(GalleryPrefsKeys.downloadMimeFilter) ?? '';
  }

  Future<void> set(String value) async {
    final prefs = PrefsService().prefs;
    await prefs.setString(GalleryPrefsKeys.downloadMimeFilter, value);
    state = value;
  }
}

/// 下载排序字段（空=默认 sync_count 升序）
@Riverpod(keepAlive: true)
class GalleryDownloadSortBy extends _$GalleryDownloadSortBy {
  @override
  String build() {
    final prefs = PrefsService().prefs;
    return prefs.getString(GalleryPrefsKeys.downloadSortBy) ?? '';
  }

  Future<void> set(String value) async {
    final prefs = PrefsService().prefs;
    await prefs.setString(GalleryPrefsKeys.downloadSortBy, value);
    state = value;
  }
}

/// 下载排序方向（asc/desc）
@Riverpod(keepAlive: true)
class GalleryDownloadSortOrder extends _$GalleryDownloadSortOrder {
  @override
  String build() {
    final prefs = PrefsService().prefs;
    return prefs.getString(GalleryPrefsKeys.downloadSortOrder) ?? 'asc';
  }

  Future<void> set(String value) async {
    final prefs = PrefsService().prefs;
    await prefs.setString(GalleryPrefsKeys.downloadSortOrder, value);
    state = value;
  }
}

/// 下载年份筛选（0=不筛选）
@Riverpod(keepAlive: true)
class GalleryDownloadYear extends _$GalleryDownloadYear {
  @override
  int build() {
    final prefs = PrefsService().prefs;
    return prefs.getInt(GalleryPrefsKeys.downloadYear) ?? 0;
  }

  Future<void> set(int value) async {
    final prefs = PrefsService().prefs;
    await prefs.setInt(GalleryPrefsKeys.downloadYear, value);
    state = value;
  }
}

/// 下载月份筛选（0=不筛选）
@Riverpod(keepAlive: true)
class GalleryDownloadMonth extends _$GalleryDownloadMonth {
  @override
  int build() {
    final prefs = PrefsService().prefs;
    return prefs.getInt(GalleryPrefsKeys.downloadMonth) ?? 0;
  }

  Future<void> set(int value) async {
    final prefs = PrefsService().prefs;
    await prefs.setInt(GalleryPrefsKeys.downloadMonth, value);
    state = value;
  }
}

/// 下载日期筛选（0=不筛选）
@Riverpod(keepAlive: true)
class GalleryDownloadDay extends _$GalleryDownloadDay {
  @override
  int build() {
    final prefs = PrefsService().prefs;
    return prefs.getInt(GalleryPrefsKeys.downloadDay) ?? 0;
  }

  Future<void> set(int value) async {
    final prefs = PrefsService().prefs;
    await prefs.setInt(GalleryPrefsKeys.downloadDay, value);
    state = value;
  }
}

/// 下载二次排序字段（空=不进行二次排序）
@Riverpod(keepAlive: true)
class GalleryDownloadSecondarySort extends _$GalleryDownloadSecondarySort {
  @override
  String build() {
    final prefs = PrefsService().prefs;
    return prefs.getString(GalleryPrefsKeys.downloadSecondarySort) ?? '';
  }

  Future<void> set(String value) async {
    final prefs = PrefsService().prefs;
    await prefs.setString(GalleryPrefsKeys.downloadSecondarySort, value);
    state = value;
  }
}
