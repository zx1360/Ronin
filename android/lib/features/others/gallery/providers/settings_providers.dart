import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/core/services/storage/prefs_service.dart';

part 'settings_providers.g.dart';

enum GalleryGridPreviewMode { thumb, preview, waterfall }

typedef GalleryBrowseOptions = ({
  bool autoOrientation,
  bool previewWindow,
  int gridColumns,
  GalleryGridPreviewMode gridMode,
  bool autoApplyTags,
});

@Riverpod(keepAlive: true)
class GalleryBrowseSettings extends _$GalleryBrowseSettings {
  static const _columns = [3, 4, 8, 16];

  @override
  GalleryBrowseOptions build() {
    final prefs = PrefsService().prefs;
    final columns = prefs.getInt('gallery_grid_columns') ?? 4;
    final mode = prefs.getString('gallery_grid_preview_mode');
    return (
      autoOrientation: prefs.getBool('gallery_auto_orientation') ?? false,
      previewWindow: prefs.getBool('gallery_preview_window_enabled') ?? true,
      gridColumns: _columns.contains(columns) ? columns : 4,
      gridMode: GalleryGridPreviewMode.values.firstWhere(
        (value) => value.name == mode,
        orElse: () => GalleryGridPreviewMode.thumb,
      ),
      autoApplyTags: prefs.getBool('gallery_tag_auto_apply') ?? false,
    );
  }

  Future<void> setAutoOrientation(bool enabled) =>
      _save(PrefsService().prefs.setBool('gallery_auto_orientation', enabled));

  Future<void> setPreviewWindow(bool enabled) => _save(
    PrefsService().prefs.setBool('gallery_preview_window_enabled', enabled),
  );

  Future<void> setGridMode(GalleryGridPreviewMode mode) => _save(
    PrefsService().prefs.setString('gallery_grid_preview_mode', mode.name),
  );

  Future<void> changeColumns(int step) async {
    final prefs = PrefsService().prefs;
    final index = _columns.indexOf(build().gridColumns);
    final next = (index + step).clamp(0, _columns.length - 1);
    if (next != index) {
      await _save(prefs.setInt('gallery_grid_columns', _columns[next]));
    }
  }

  Future<void> setAutoApplyTags(bool enabled) =>
      _save(PrefsService().prefs.setBool('gallery_tag_auto_apply', enabled));

  Future<void> _save(Future<void> write) async {
    await write;
    if (ref.mounted) state = build();
  }
}

typedef GalleryDownloadOptions = ({
  String mimeType,
  String sortBy,
  String sortOrder,
  int year,
  int month,
  int day,
});

@Riverpod(keepAlive: true)
class GalleryDownloadFilters extends _$GalleryDownloadFilters {
  @override
  GalleryDownloadOptions build() {
    final prefs = PrefsService().prefs;
    final year = prefs.getInt('gallery_download_year') ?? 0;
    final month = year == 0
        ? 0
        : (prefs.getInt('gallery_download_month') ?? 0).clamp(0, 12);
    return (
      mimeType: prefs.getString('gallery_download_mime_filter') ?? '',
      sortBy: prefs.getString('gallery_download_sort_by') ?? '',
      sortOrder: prefs.getString('gallery_download_sort_order') ?? 'asc',
      year: year,
      month: month,
      day: month == 0
          ? 0
          : (prefs.getInt('gallery_download_day') ?? 0).clamp(0, 31),
    );
  }

  Future<void> update({
    String? mimeType,
    String? sortBy,
    String? sortOrder,
    int? year,
    int? month,
    int? day,
  }) async {
    final prefs = PrefsService().prefs;
    if (year == 0) month = 0;
    if (month == 0) day = 0;
    await Future.wait([
      if (mimeType != null)
        prefs.setString('gallery_download_mime_filter', mimeType),
      if (sortBy != null) prefs.setString('gallery_download_sort_by', sortBy),
      if (sortOrder != null)
        prefs.setString('gallery_download_sort_order', sortOrder),
      if (year != null) prefs.setInt('gallery_download_year', year),
      if (month != null) prefs.setInt('gallery_download_month', month),
      if (day != null) prefs.setInt('gallery_download_day', day),
    ]);
    if (ref.mounted) state = build();
  }
}
