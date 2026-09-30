import 'dart:async';

import 'package:northstar/core/providers/ai/ai_providers.dart';
import 'package:northstar/core/providers/ops/ops_overview_provider.dart';
import 'package:northstar/core/providers/ops/ops_settings_provider.dart';
import 'package:northstar/domain/ai/models/ai_models.dart';
import 'package:northstar/domain/gallery/models/gallery_media.dart';
import 'package:northstar/infrastructure/gallery/gallery_api_client.dart';
import 'package:northstar/infrastructure/ops/file_reveal_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'gallery_providers.g.dart';

/// 画廊 API 客户端单例。
@Riverpod(keepAlive: true)
GalleryApiClient galleryApiClient(GalleryApiClientRef ref) {
  final client = GalleryApiClient();
  ref.onDispose(client.dispose);
  return client;
}

/// 服务端 gallery/Media 的绝对路径（用于「打开所在目录」）。
///
/// 取值来自 `/API/ops/overview`；尚未取到时由调用方提示重试，
/// 绝不猜测路径（猜错会打开错误的目录）。
@Riverpod(keepAlive: true)
String? galleryMediaRoot(GalleryMediaRootRef ref) {
  final overview = ref.watch(opsOverviewControllerProvider).overview;
  return overview?.storage['galleryMedia']?.path;
}

/// 把库内相对路径解析为绝对路径（根目录未知时返回 null）。
String? resolveMediaPath(String? mediaRoot, String filePath) {
  if (mediaRoot == null || mediaRoot.isEmpty) return null;
  return FileRevealService.absoluteMediaPath(mediaRoot, filePath);
}

/// 软删除媒体列表（分页累积）。
class DeletedMediaState {
  final List<GalleryMedia> items;
  final int total;
  final bool loading;
  final String? error;
  final Set<String> selection;

  const DeletedMediaState({
    this.items = const [],
    this.total = 0,
    this.loading = false,
    this.error,
    this.selection = const {},
  });

  bool get hasMore => items.length < total;

  DeletedMediaState copyWith({
    List<GalleryMedia>? items,
    int? total,
    bool? loading,
    String? error,
    Set<String>? selection,
    bool clearError = false,
  }) {
    return DeletedMediaState(
      items: items ?? this.items,
      total: total ?? this.total,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      selection: selection ?? this.selection,
    );
  }
}

/// 软删除媒体列表控制器：按需加载 + 多选 + 取消软删除。
@Riverpod(keepAlive: true)
class DeletedMediaController extends _$DeletedMediaController {
  static const int _pageSize = 120;

  @override
  DeletedMediaState build() => const DeletedMediaState();

  Future<void> load({bool more = false}) async {
    if (state.loading) return;
    if (more && !state.hasMore) return;

    state = state.copyWith(loading: true, clearError: true);
    try {
      final settings = ref.read(opsSettingsControllerProvider);
      final page = await ref.read(galleryApiClientProvider).fetchMedia(
            settings,
            onlyDeleted: true,
            limit: _pageSize,
            offset: more ? state.items.length : 0,
          );
      final items = more ? [...state.items, ...page.items] : page.items;
      final alive = items.map((item) => item.id).toSet();
      state = state.copyWith(
        items: items,
        total: page.total,
        loading: false,
        selection: state.selection.intersection(alive),
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void toggle(String id) {
    final selection = {...state.selection};
    if (!selection.remove(id)) selection.add(id);
    state = state.copyWith(selection: selection);
  }

  void clearSelection() => state = state.copyWith(selection: const {});

  /// 取消选中项的软删除标记，并把它们从列表中移除。
  Future<int> restoreSelected() async {
    final ids = state.selection.toList();
    if (ids.isEmpty) return 0;
    final settings = ref.read(opsSettingsControllerProvider);
    final count = await ref.read(galleryApiClientProvider).setDeleted(
          settings,
          ids,
          deleted: false,
        );
    final restored = ids.toSet();
    final items =
        state.items.where((item) => !restored.contains(item.id)).toList();
    state = state.copyWith(
      items: items,
      total: (state.total - count).clamp(0, 1 << 30),
      selection: const {},
    );
    return count;
  }
}

/// 被标记为「非重复」的媒体（可恢复）。
@Riverpod(keepAlive: true)
Future<List<GalleryMedia>> ignoredDuplicates(IgnoredDuplicatesRef ref) {
  final settings = ref.watch(opsSettingsControllerProvider);
  return ref.read(aiApiClientProvider).fetchIgnoredDuplicates(settings);
}

/// 近重复分组（含已忽略数量）。
class DuplicatesResult {
  final List<AiDuplicateGroup> groups;
  final int ignoredTotal;

  const DuplicatesResult({required this.groups, required this.ignoredTotal});
}

@Riverpod(keepAlive: true)
Future<DuplicatesResult> duplicateGroups(DuplicateGroupsRef ref) async {
  final settings = ref.watch(opsSettingsControllerProvider);
  final result =
      await ref.read(aiApiClientProvider).fetchDuplicates(settings);
  return DuplicatesResult(
    groups: result.groups,
    ignoredTotal: result.ignoredTotal,
  );
}
