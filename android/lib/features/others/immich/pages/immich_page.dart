import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/app/theme/theme_book.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/models/tag.dart';
import 'package:torrid/features/others/gallery/providers/gallery_providers.dart';
import 'package:torrid/features/others/immich/providers/immich_providers.dart';
import 'package:torrid/features/others/immich/widgets/album_media_viewer.dart';
import 'package:torrid/features/others/immich/widgets/immich_ai_tag_sheet.dart';
import 'package:torrid/features/others/immich/widgets/immich_dialogs.dart';
import 'package:torrid/features/others/immich/widgets/immich_media_grid.dart';
import 'package:torrid/features/others/immich/widgets/immich_ops_sheet.dart';
import 'package:torrid/features/others/immich/widgets/immich_tag_tree.dart';
import 'package:torrid/features/others/services/media_share_service.dart';
import 'package:torrid/features/others/smart_album/pages/smart_album_page.dart';
import 'package:torrid/features/others/smart_album/providers/smart_album_providers.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

class ImmichPage extends ConsumerStatefulWidget {
  const ImmichPage({super.key});

  @override
  ConsumerState<ImmichPage> createState() => _ImmichPageState();
}

class _ImmichPageState extends ConsumerState<ImmichPage>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 3, vsync: this);
  int _tab = 0;
  bool _selectionMode = false;

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (_tab == _tabs.index) return;
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() => _tab = _tabs.index);
    });
    Future.microtask(() async {
      try {
        if (!mounted) return;
        await ref.read(tagTreeProvider.notifier).syncFromServer();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaAsync = ref.watch(immichMediaProvider);
    final page = mediaAsync.hasError ? null : mediaAsync.valueOrNull;
    final selection = ref.watch(immichSelectionProvider);
    final busy = ref.watch(immichActionsProvider);
    final tags = ref.watch(tagTreeProvider).valueOrNull ?? const <Tag>[];
    final tagById = {for (final tag in tags) tag.id: tag};
    final search = ref.watch(smartAlbumControllerProvider.notifier);
    ref.listen(immichFilterNotifierProvider, (_, __) => _clearSelection());
    final selected = [
      for (final asset in page?.assets ?? const <MediaAsset>[])
        if (selection.contains(asset.id)) asset,
    ];

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('相册'),
        bottom: AppTheme.appBarTabs(
          Theme.of(context).colorScheme,
          controller: _tabs,
          tabs: const [
            Tab(text: '照片'),
            Tab(text: '检索'),
            Tab(text: '人物'),
          ],
        ),
        actions: _tab != 0
            ? null
            : [
                Builder(
                  builder: (context) => IconButton(
                    tooltip: '标签与筛选',
                    icon: const Icon(Icons.filter_list),
                    onPressed: busy
                        ? null
                        : () => Scaffold.of(context).openDrawer(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.sync),
                  tooltip: '同步',
                  onPressed: busy ? null : _sync,
                ),
                IconButton(
                  icon: Icon(_selectionMode ? Icons.close : Icons.checklist),
                  tooltip: _selectionMode ? '退出多选' : '多选',
                  onPressed: busy || mediaAsync.isLoading
                      ? null
                      : _toggleSelectionMode,
                ),
              ],
      ),
      drawer: const ImmichTagTreePanel(),
      drawerEnableOpenDragGesture: _tab == 0 && !busy,
      body: SafeArea(
        top: false,
        child: TabBarView(
          controller: _tabs,
          children: [
            Column(
              children: [
                _buildFilterBar(),
                Expanded(
                  child: _buildBody(mediaAsync, page, selection, tagById, busy),
                ),
              ],
            ),
            const SmartAlbumSearch(),
            SmartAlbumPeople(
              onPerson: (person) {
                if (busy) return;
                _tabs.animateTo(1);
                search.searchByPerson(person);
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: _tab != 0 || selected.isEmpty
          ? null
          : ImmichSelectionBar(
              count: selected.length,
              busy: busy || mediaAsync.isLoading,
              onAddTags: _addTagsToSelection,
              onRemoveTags: _removeTagsFromSelection,
              onDelete: selected.any((asset) => !asset.isDeleted)
                  ? () => _setDeleted(selected, true)
                  : null,
              onRestore: selected.any((asset) => asset.isDeleted)
                  ? () => _setDeleted(selected, false)
                  : null,
              onMessage: _editSelectionMessage,
              onBundle: selected.length >= 2
                  ? () => _bundleSelection(selected)
                  : null,
              onUnbundle: selected.any((asset) => asset.isGroupMember)
                  ? () => _unbundleSelection(selected)
                  : null,
              onClear: _clearSelection,
              onShare: () {
                showMediaShareDialog(
                  context,
                  ref.read(apiClientManagerProvider),
                  selected,
                );
              },
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
    final active =
        filter.tagIds.isNotEmpty ||
        filter.untagged ||
        filter.includeDeleted ||
        filter.vlmTags.isNotEmpty ||
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
                label: const Text('含待删除', style: TextStyle(fontSize: 12)),
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

        // 第四行: AI 标签 (只读, 服务端 VLM 自动生成, 与人工标签分开呈现)
        _buildAiTagRow(filter, notifier),
      ],
    );
  }

  /// AI 标签筛选入口；没有可用 AI 标签时整行不出现。
  ///
  /// 只保留一个入口按钮 + 已选条件，完整列表（可搜索、带次数）在弹出面板里，
  /// 避免把几十个标签塞进筛选栏挤占空间。
  Widget _buildAiTagRow(ImmichFilter filter, ImmichFilterNotifier notifier) {
    final aiTags = ref.watch(immichAiTagsProvider).valueOrNull;
    if (aiTags == null || aiTags.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => showImmichAiTagSheet(context),
                icon: const Icon(
                  Icons.auto_awesome,
                  size: 18,
                  color: Colors.teal,
                ),
                tooltip: 'AI 标签筛选',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(width: 2),
              Text(
                'AI 标签',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(width: 6),
              TextButton(
                onPressed: () => showImmichAiTagSheet(context),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(
                  filter.vlmTags.isEmpty
                      ? '筛选（${aiTags.length} 个）'
                      : '已选 ${filter.vlmTags.length} 个 · 修改',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          // 已选 AI 标签单独一行，明确它们与人工标签筛选互不影响
          if (filter.vlmTags.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final tag in filter.vlmTags)
                  InputChip(
                    label: Text(tag, style: const TextStyle(fontSize: 12)),
                    avatar: const Icon(Icons.auto_awesome, size: 14),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onDeleted: () => notifier.toggleVlmTag(tag),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  // 主体

  Widget _buildBody(
    AsyncValue<ImmichMediaPage> mediaAsync,
    ImmichMediaPage? page,
    Set<String> selection,
    Map<String, Tag> tagById,
    bool busy,
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
            const Icon(
              Icons.photo_library_outlined,
              size: 56,
              color: Colors.grey,
            ),
            const SizedBox(height: 12),
            const Text('没有符合条件的媒体', style: TextStyle(color: Colors.grey)),
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
        AlbumMediaGrid(
          key: const PageStorageKey('album-photos'),
          assets: page.assets,
          labelsFor: (asset) => [
            for (final id in page.tagIdsByMedia[asset.id] ?? const <String>[])
              if (tagById[id] case final tag?) tag.name,
          ],
          selectionMode: _selectionMode,
          selectedIds: selection,
          loadingMore: page.loadingMore,
          onLoadMore: page.hasMore && !busy ? _loadMore : null,
          onRefresh: _refresh,
          onTap: (asset) {
            if (!busy && !mediaAsync.isLoading) _onTapAsset(asset);
          },
          onLongPress: (asset) {
            if (!busy && !mediaAsync.isLoading) _onLongPressAsset(asset);
          },
        ),
        if (mediaAsync.isLoading || busy)
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
    _openViewer(asset.id);
  }

  void _openViewer(String mediaId) {
    final assets =
        ref.read(immichMediaProvider).valueOrNull?.assets ?? const [];
    openAlbumMediaViewer(
      context,
      assets: assets,
      mediaId: mediaId,
      onSimilar: (asset) {
        _tabs.animateTo(1);
        ref.read(smartAlbumControllerProvider.notifier).searchSimilar(asset);
      },
    );
  }

  void _onLongPressAsset(MediaAsset asset) {
    if (!_selectionMode) setState(() => _selectionMode = true);
    ref.read(immichSelectionProvider.notifier).toggle(asset.id);
  }

  void _clearSelection() {
    if (!_selectionMode) return;
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
    if (!mounted || picked == null || picked.isEmpty) return;
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
    if (!mounted || picked == null || picked.isEmpty) return;
    await _run(
      () => ref
          .read(immichActionsProvider.notifier)
          .removeTags(ids, picked.toList()),
      ok: '已移除标签',
    );
  }

  Future<void> _setDeleted(List<MediaAsset> selected, bool deleted) async {
    final ids = [
      for (final asset in selected)
        if (asset.isDeleted != deleted) asset.id,
    ];
    if (deleted && !await confirmAlbumDeletion(context, ids.length)) return;
    if (!mounted) return;
    await _run(
      () => ref.read(immichActionsProvider.notifier).setDeleted(ids, deleted),
      ok: deleted ? '已标记待删除，可在「含待删除」中恢复' : '已恢复 ${ids.length} 项',
    );
  }

  Future<void> _editSelectionMessage() async {
    final ids = _selectedIdsOrdered;
    if (ids.isEmpty) return;
    final assets = _assetsByIds(ids, ref.read(immichMediaProvider).valueOrNull);
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
    if (!mounted || text == null) return;
    await _run(
      () => ref.read(immichActionsProvider.notifier).setMessage(ids, text),
      ok: '备注已更新',
    );
  }

  Future<void> _bundleSelection(List<MediaAsset> selected) async {
    final bundle = await showImmichBundleDialog(context, selected);
    if (!mounted || bundle == null) return;
    await _run(
      () => ref
          .read(immichActionsProvider.notifier)
          .bundle(bundle.leadId, bundle.memberIds),
      ok: '已捆绑所选媒体',
    );
  }

  Future<void> _unbundleSelection(List<MediaAsset> selected) async {
    final ids = [
      for (final asset in selected)
        if (asset.isGroupMember) asset.id,
    ];
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
      _clearSelection();
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
