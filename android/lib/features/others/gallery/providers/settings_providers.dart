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
