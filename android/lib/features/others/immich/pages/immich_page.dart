import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/models/tag.dart';
import 'package:torrid/features/others/gallery/providers/gallery_providers.dart';
import 'package:torrid/features/others/immich/providers/immich_providers.dart';
import 'package:torrid/features/others/immich/widgets/immich_dialogs.dart';
import 'package:torrid/features/others/immich/widgets/immich_media_grid.dart';
import 'package:torrid/features/others/immich/widgets/immich_ops_sheet.dart';
import 'package:torrid/features/others/immich/widgets/immich_tag_tree.dart';

/// 相册页 (immich)
///
/// 始终在线的媒体/标签管理页: 数据直连局域网后端, 同时把结果镜像回本地缓存。
/// - 标签树 (Drawer): 浏览/筛选/新建/重命名/移动/删除/快捷标签
/// - 媒体网格: 分页浏览, 多选批量加标签/移除标签/删除/恢复/备注/捆绑/解绑
/// - 单张媒体: 详情弹窗, 编辑备注与标签
class ImmichPage extends ConsumerStatefulWidget {
  const ImmichPage({super.key});

  @override
  ConsumerState<ImmichPage> createState() => _ImmichPageState();
}

class _ImmichPageState extends ConsumerState<ImmichPage> {
  bool _selectionMode = false;

  @override
  void initState() {
    super.initState();
    // 服务端为权威: 进入页面时同步一次标签 (失败则继续用本地缓存)
    Future.microtask(() async {
      try {
        await ref.read(tagTreeProvider.notifier).syncFromServer();
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaAsync = ref.watch(immichMediaProvider);
    final page = mediaAsync.valueOrNull;
    final selection = ref.watch(immichSelectionProvider);
    final busy = ref.watch(immichActionsProvider);
    final tags = ref.watch(tagTreeProvider).valueOrNull ?? const <Tag>[];
    final tagById = {for (final tag in tags) tag.id: tag};

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('相册'),
            if (page != null)
              Text(
                '${page.total} 项',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: [
          if (busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: '同步',
            onPressed: _sync,
          ),
          IconButton(
            icon: Icon(_selectionMode ? Icons.close : Icons.checklist),
            tooltip: _selectionMode ? '退出多选' : '多选',
            onPressed: _toggleSelectionMode,
          ),
        ],
      ),
      drawer: const ImmichTagTreePanel(),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(child: _buildBody(mediaAsync, page, selection, tagById)),
        ],
      ),
      bottomNavigationBar: selection.isEmpty
          ? null
          : ImmichSelectionBar(
              count: selection.length,
              onAddTags: _addTagsToSelection,
              onRemoveTags: _removeTagsFromSelection,
              onDelete: _deleteSelection,
              onRestore: _restoreSelection,
              onMessage: _editSelectionMessage,
              onBundle: _bundleSelection,
              onUnbundle: _unbundleSelection,
              onClear: _clearSelection,
            ),
    );
  }

  // 筛选栏

  Widget _buildFilterBar() {
    final filter = ref.watch(immichFilterNotifierProvider);
    final notifier = ref.read(immichFilterNotifierProvider.notifier);
    final tags = ref.watch(tagTreeProvider).valueOrNull ?? const <Tag>[];
    final byId = {for (final tag in tags) tag.id: tag};
    final favorites = ref.watch(favoriteTagsProvider);
    final total = ref.watch(immichMediaProvider).valueOrNull?.total;
    final active = filter.tagIds.isNotEmpty ||
        filter.untagged ||
        filter.includeDeleted ||
        !filter.includeDescendants;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 第一行: 条件开关 + 结果数
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
          child: Row(
            children: [
              FilterChip(
                label: const Text('未打标签', style: TextStyle(fontSize: 12)),
                selected: filter.untagged,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onSelected: (_) => notifier.toggleUntagged(),
              ),
              if (filter.tagIds.isNotEmpty) ...[
                const SizedBox(width: 6),
                FilterChip(
                  label: const Text('含子标签', style: TextStyle(fontSize: 12)),
                  selected: filter.includeDescendants,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onSelected: notifier.setIncludeDescendants,
                ),
              ],
              const SizedBox(width: 6),
              FilterChip(
                label: const Text('含已删除', style: TextStyle(fontSize: 12)),
                selected: filter.includeDeleted,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onSelected: notifier.setIncludeDeleted,
              ),
              const SizedBox(width: 8),
              Text(
                total == null ? '加载中…' : '共 $total 项',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              if (active) ...[
                const SizedBox(width: 4),
                TextButton(
                  onPressed: notifier.reset,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('清空', style: TextStyle(fontSize: 12)),
                ),
              ],
            ],
          ),
        ),

        // 第二行: 已选标签（可单个移除）
        if (filter.tagIds.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
            child: Row(
              children: [
                const Icon(Icons.filter_alt, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                for (final id in filter.tagIds) ...[
                  Tooltip(
                    message: byId[id]?.fullPath ?? '',
                    child: InputChip(
                      label: Text(
                        byId[id]?.name ?? '未知标签',
                        style: const TextStyle(fontSize: 12),
                      ),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onDeleted: () => notifier.toggleTag(id),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),

        // 第三行: 快捷标签一键筛选
        if (favorites.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
            child: Row(
              children: [
                Icon(Icons.star, size: 14, color: Colors.amber[700]),
                const SizedBox(width: 4),
                for (final tag in favorites) ...[
                  FilterChip(
                    label: Text(tag.name, style: const TextStyle(fontSize: 12)),
                    selected: filter.tagIds.contains(tag.id),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onSelected: (_) => notifier.toggleTag(tag.id),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
      ],
    );
  }

  // 主体

  Widget _buildBody(
    AsyncValue<ImmichMediaPage> mediaAsync,
    ImmichMediaPage? page,
    Set<String> selection,
    Map<String, Tag> tagById,
  ) {
    if (page == null) {
      return mediaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  '加载失败: $error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(immichMediaProvider),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (_) => const SizedBox.shrink(),
      );
    }

    if (page.assets.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.photo_library_outlined,
                size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('没有符合条件的媒体',
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                ref.read(immichFilterNotifierProvider.notifier).reset();
                ref.invalidate(immichMediaProvider);
              },
              child: const Text('清除筛选'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        ImmichMediaGrid(
          page: page,
          tagById: tagById,
          selectionMode: _selectionMode,
          selectedIds: selection,
          selectionOrder: selection.toList(),
          onLoadMore: _loadMore,
          onRefresh: _refresh,
          onTap: _onTapAsset,
          onLongPress: _onLongPressAsset,
        ),
        if (mediaAsync.isLoading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }

  // 基础交互

  Future<void> _sync() async {
    try {
      await ref.read(tagTreeProvider.notifier).syncFromServer();
      await ref.read(immichMediaProvider.notifier).refresh();
      _snack('已同步');
    } catch (e) {
      _snack('同步失败: $e');
    }
  }

  Future<void> _refresh() async {
    try {
      await ref.read(immichMediaProvider.notifier).refresh();
    } catch (e) {
      _snack('刷新失败: $e');
    }
  }

  Future<void> _loadMore() async {
    try {
      await ref.read(immichMediaProvider.notifier).loadMore();
    } catch (e) {
      _snack('加载更多失败: $e');
    }
  }

  void _toggleSelectionMode() {
    setState(() => _selectionMode = !_selectionMode);
    if (!_selectionMode) {
      ref.read(immichSelectionProvider.notifier).clear();
    }
  }

  void _onTapAsset(MediaAsset asset) {
    if (_selectionMode) {
      ref.read(immichSelectionProvider.notifier).toggle(asset.id);
      return;
    }
    showImmichMediaDetail(context, mediaId: asset.id, fallback: asset);
  }

  void _onLongPressAsset(MediaAsset asset) {
    if (!_selectionMode) setState(() => _selectionMode = true);
    ref.read(immichSelectionProvider.notifier).toggle(asset.id);
  }

  void _clearSelection() {
    ref.read(immichSelectionProvider.notifier).clear();
    setState(() => _selectionMode = false);
  }

  /// 选中项 id (按网格顺序, 首位作为捆绑主文件的默认值)
  List<String> get _selectedIdsOrdered {
    final page = ref.read(immichMediaProvider).valueOrNull;
    final selection = ref.read(immichSelectionProvider);
    if (page == null) return selection.toList();
    return [
      for (final asset in page.assets)
        if (selection.contains(asset.id)) asset.id,
    ];
  }

  List<MediaAsset> _assetsByIds(List<String> ids, ImmichMediaPage? page) {
    final byId = {
      for (final asset in page?.assets ?? const <MediaAsset>[]) asset.id: asset,
    };
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  // 批量操作

  Future<void> _addTagsToSelection() async {
    final ids = _selectedIdsOrdered;
    if (ids.isEmpty) return;
    final picked = await showImmichTagPicker(context, title: '添加标签');
    if (picked == null || picked.isEmpty) return;
    await _run(
      () => ref
          .read(immichActionsProvider.notifier)
          .addTags(ids, picked.toList()),
      ok: '已为 ${ids.length} 项添加标签',
    );
  }

  Future<void> _removeTagsFromSelection() async {
    final ids = _selectedIdsOrdered;
    if (ids.isEmpty) return;
    final page = ref.read(immichMediaProvider).valueOrNull;
    final present = <String>{};
    for (final id in ids) {
      present.addAll(page?.tagIdsByMedia[id] ?? const <String>[]);
    }
    if (present.isEmpty) {
      _snack('选中的媒体没有标签');
      return;
    }
    final picked = await showImmichTagPicker(
      context,
      title: '移除标签',
      restrictTo: present,
    );
    if (picked == null || picked.isEmpty) return;
    await _run(
      () => ref
          .read(immichActionsProvider.notifier)
          .removeTags(ids, picked.toList()),
      ok: '已移除标签',
    );
  }

  Future<void> _deleteSelection() async {
    final ids = _selectedIdsOrdered;
    if (ids.isEmpty) return;
    final confirmed = await showImmichConfirmDialog(
      context,
      title: '删除媒体',
      message: '确定软删除选中的 ${ids.length} 项吗?',
      confirmText: '删除',
      danger: true,
    );
    if (!confirmed) return;
    await _run(
      () => ref.read(immichActionsProvider.notifier).setDeleted(ids, true),
      ok: '已删除 ${ids.length} 项',
    );
  }

  Future<void> _restoreSelection() async {
    final ids = _selectedIdsOrdered;
    if (ids.isEmpty) return;
    await _run(
      () => ref.read(immichActionsProvider.notifier).setDeleted(ids, false),
      ok: '已恢复 ${ids.length} 项',
    );
  }

  Future<void> _editSelectionMessage() async {
    final ids = _selectedIdsOrdered;
    if (ids.isEmpty) return;
    final assets = _assetsByIds(
      ids,
      ref.read(immichMediaProvider).valueOrNull,
    );
    final first = assets.isEmpty ? null : assets.first.message;
    final same = assets.every((a) => (a.message ?? '') == (first ?? ''));
    final text = await showImmichTextDialog(
      context,
      title: '编辑备注 (${ids.length} 项)',
      initial: same ? (first ?? '') : '',
      label: '备注',
      hint: same ? '留空即清除备注' : '多项备注不同, 输入将覆盖为同一备注',
      maxLines: 3,
    );
    if (text == null) return;
    await _run(
      () => ref.read(immichActionsProvider.notifier).setMessage(ids, text),
      ok: '备注已更新',
    );
  }

  Future<void> _bundleSelection() async {
    final ids = _selectedIdsOrdered;
    if (ids.length < 2) {
      _snack('请至少选择两个媒体');
      return;
    }
    final assets = _assetsByIds(
      ids,
      ref.read(immichMediaProvider).valueOrNull,
    );
    if (assets.length < 2) {
      _snack('请至少选择两个媒体');
      return;
    }
    final leadId = await showImmichLeadPicker(context, assets);
    if (leadId == null) return;
    final members = [
      for (final id in ids)
        if (id != leadId) id,
    ];
    await _run(
      () => ref.read(immichActionsProvider.notifier).bundle(leadId, members),
      ok: '已捆绑 ${members.length} 项',
    );
  }

  Future<void> _unbundleSelection() async {
    final ids = _selectedIdsOrdered;
    if (ids.isEmpty) return;
    await _run(
      () => ref.read(immichActionsProvider.notifier).unbundle(ids),
      ok: '已解绑 ${ids.length} 项',
    );
  }

  /// 执行批量操作: 统一错误提示并在成功后退出多选
  Future<void> _run(Future<void> Function() action, {String? ok}) async {
    try {
      await action();
      if (!mounted) return;
      setState(() => _selectionMode = false);
      if (ok != null) _snack(ok);
    } catch (e) {
      _snack('操作失败: $e');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }
}
