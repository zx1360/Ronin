import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/album/models/ai_search_models.dart';
import 'package:torrid/features/album/services/ai_api_service.dart';
import 'package:torrid/features/gallery/models/media_asset.dart';
import 'package:torrid/features/album/providers/album_providers.dart';
import 'package:torrid/features/album/widgets/album_media_viewer.dart';
import 'package:torrid/features/album/widgets/album_dialogs.dart';
import 'package:torrid/features/album/widgets/album_media_grid.dart';
import 'package:torrid/features/album/widgets/album_ops_sheet.dart';
import 'package:torrid/features/album/widgets/album_tag_picker.dart';
import 'package:torrid/features/album/providers/album_search_provider.dart';
import 'package:torrid/features/album/widgets/album_search_filters.dart';

class AlbumSearchTab extends ConsumerStatefulWidget {
  const AlbumSearchTab({super.key});

  @override
  ConsumerState<AlbumSearchTab> createState() => _AlbumSearchTabState();
}

class _AlbumSearchTabState extends ConsumerState<AlbumSearchTab>
    with AutomaticKeepAliveClientMixin {
  static const _sourceLabels = {
    'ocr': '识别文字',
    'caption': 'AI 描述',
    'vlm_tag': 'AI 标签',
  };

  final _text = TextEditingController();
  final _selected = <String>{};
  AiSearchResult? _displayedResult;
  List<MediaAsset> _assets = const [];
  Map<String, List<String>> _sourcesById = const {};
  bool _selecting = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _clearSelection() {
    if (!_selecting) return;
    setState(() {
      _selecting = false;
      _selected.clear();
    });
  }

  void _toggle(MediaAsset asset) {
    setState(() {
      _selecting = true;
      if (!_selected.remove(asset.id)) _selected.add(asset.id);
    });
  }

  void _updateDisplay(AiSearchResult result) {
    if (identical(_displayedResult, result)) return;
    _displayedResult = result;
    _assets = [for (final hit in result.hits) hit.asset];
    _sourcesById = result.mode == 'keyword'
        ? {for (final hit in result.hits) hit.id: hit.sources}
        : const {};
  }

  List<String> _labelsFor(MediaAsset asset) {
    if (_displayedResult?.mode == 'filename') {
      final path = asset.filePath;
      final separator = path.lastIndexOf(RegExp(r'[/\\]'));
      return [path.substring(separator + 1)];
    }
    return [
      for (final source in _sourcesById[asset.id] ?? const <String>[])
        if (_sourceLabels[source] case final label?) label,
    ];
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = ref.watch(albumSearchControllerProvider);
    final controller = ref.read(albumSearchControllerProvider.notifier);
    final busy = ref.watch(albumActionsProvider);
    ref.listen(albumSearchControllerProvider.select((value) => value.subject), (
      _,
      subject,
    ) {
      if (subject.isNotEmpty) _text.clear();
    });
    ref.listen(
      albumSearchControllerProvider.select((value) => value.revision),
      (_, __) => _clearSelection(),
    );
    final result = state.result;
    _updateDisplay(result);
    final assets = _assets;
    final selected = _selected.isEmpty
        ? const <MediaAsset>[]
        : assets.where((asset) => _selected.contains(asset.id)).toList();
    final canRank = result.mode == 'semantic';
    final theme = Theme.of(context);
    final canSelect = !busy && assets.isNotEmpty;
    final matchKind = state.subject.isNotEmpty || state.queryText.isEmpty
        ? ''
        : switch (result.mode) {
            'semantic' => '智能匹配',
            'keyword' when state.mode == AiSearchMode.auto => '语义暂不可用，已按文字匹配',
            'keyword' => '文字匹配',
            'filename' => '文件名匹配',
            _ => '',
          };
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: TextField(
            controller: _text,
            enabled: !busy,
            textInputAction: TextInputAction.search,
            onChanged: (text) {
              if (text.trim().isEmpty && state.queryText.isNotEmpty) {
                controller.search(text);
              }
            },
            onSubmitted: controller.search,
            decoration: InputDecoration(
              hintText: switch (state.mode) {
                AiSearchMode.filename => '文件名或扩展名',
                AiSearchMode.keyword => '画面描述、识别文字或 AI 标签',
                AiSearchMode.auto => '描述想找的画面',
              },
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: IconButton(
                tooltip: '检索',
                icon: const Icon(Icons.search),
                onPressed: busy
                    ? null
                    : () {
                        FocusScope.of(context).unfocus();
                        controller.search(_text.text);
                      },
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      DropdownButton<AiSearchMode>(
                        value: state.mode,
                        underline: const SizedBox.shrink(),
                        onChanged: busy || state.subject.isNotEmpty
                            ? null
                            : (mode) {
                                if (mode != null && mode != state.mode) {
                                  controller.search(_text.text, mode: mode);
                                }
                              },
                        items: [
                          for (final mode in AiSearchMode.values)
                            DropdownMenuItem(
                              value: mode,
                              child: Text(mode.label),
                            ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        avatar: const Icon(Icons.tune, size: 16),
                        label: Text(
                          state.filters.count == 0
                              ? '筛选'
                              : '筛选 ${state.filters.count}',
                        ),
                        selected: state.filters.count > 0,
                        showCheckmark: false,
                        onSelected: busy
                            ? null
                            : (_) => _chooseFilters(state.filters),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('含待删除'),
                        selected: state.includeDeleted,
                        onSelected: busy ? null : controller.setIncludeDeleted,
                      ),
                      if (canRank) ...[
                        const SizedBox(width: 8),
                        PopupMenuButton<bool>(
                          enabled: !busy,
                          tooltip: '结果排序',
                          onSelected: controller.setTimeline,
                          itemBuilder: (context) => [
                            CheckedPopupMenuItem(
                              value: true,
                              checked: state.timeline,
                              child: const Text('按拍摄日期'),
                            ),
                            CheckedPopupMenuItem(
                              value: false,
                              checked: !state.timeline,
                              child: const Text('按相关度'),
                            ),
                          ],
                          child: Text(state.timeline ? '按日期 ▾' : '相关度 ▾'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: _selecting ? '退出多选' : '多选',
                onPressed: !canSelect
                    ? null
                    : _selecting
                    ? _clearSelection
                    : () => setState(() => _selecting = true),
                icon: Icon(_selecting ? Icons.close : Icons.checklist),
              ),
            ],
          ),
        ),
        if (state.subject.isNotEmpty ||
            state.queryText.isNotEmpty ||
            state.filters.count > 0)
          ListTile(
            dense: true,
            title: Text(
              state.subject.isNotEmpty
                  ? state.subject
                  : state.queryText.isNotEmpty
                  ? '“${state.queryText}”'
                  : '按条件检索',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: result.mode.isEmpty
                ? null
                : Text(
                    [
                      if (matchKind.isNotEmpty) matchKind,
                      '命中 ${result.total} 项',
                    ].join(' · '),
                  ),
            trailing: IconButton(
              tooltip: '清空结果',
              onPressed: busy
                  ? null
                  : () {
                      _text.clear();
                      controller.clearResult();
                    },
              icon: const Icon(Icons.clear),
            ),
          ),
        if (state.loading) const LinearProgressIndicator(minHeight: 2),
        if (state.error case final error?)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    error,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
                TextButton(
                  onPressed: assets.isEmpty
                      ? controller.reload
                      : controller.loadMore,
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        Expanded(
          child: assets.isEmpty
              ? Center(
                  child: Text(
                    state.loading
                        ? '检索中…'
                        : state.error != null
                        ? '暂时无法检索'
                        : result.mode.isEmpty
                        ? '输入关键词、设置筛选，或从照片发起以图搜图'
                        : '没有匹配的媒体',
                  ),
                )
              : AlbumMediaGrid(
                  key: ValueKey(state.revision),
                  assets: assets,
                  labelsFor: _labelsFor,
                  timeline: state.timeline || !canRank,
                  selectedIds: _selected,
                  selectionMode: _selecting,
                  loadingMore: state.loadingMore,
                  autoLoadMore: !busy && state.error == null,
                  onLoadMore: state.hasMore && !busy
                      ? controller.loadMore
                      : null,
                  onRefresh: () async {
                    if (!busy) await controller.reload();
                  },
                  onLongPress: (asset) {
                    if (!busy) _toggle(asset);
                  },
                  onTap: (asset) {
                    if (busy) return;
                    if (_selecting) {
                      _toggle(asset);
                    } else {
                      openAlbumMediaViewer(
                        context,
                        assets: assets,
                        mediaId: asset.id,
                        scores: {
                          for (final hit in result.hits) hit.id: hit.score,
                        },
                        onSimilar: controller.searchSimilar,
                      );
                    }
                  },
                ),
        ),
        if (selected.isNotEmpty)
          AlbumSelectionBar(
            count: selected.length,
            busy: busy,
            onClear: _clearSelection,
            onEditTags: (remove) => editAlbumSelectionTags(
              context,
              ref,
              selected,
              remove: remove,
              onApplied: _clearSelection,
            ),
            onBundle: selected.length >= 2 ? () => _bundle(selected) : null,
            onUnbundle: selected.any((asset) => asset.isGroupMember)
                ? () => _unbundle(selected)
                : null,
            onDelete: selected.any((asset) => !asset.isDeleted)
                ? () => _setDeleted(selected, true)
                : null,
            onRestore: selected.any((asset) => asset.isDeleted)
                ? () => _setDeleted(selected, false)
                : null,
          ),
      ],
    );
  }

  Future<void> _chooseFilters(AlbumSearchFilters current) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await showAlbumSearchFilters(context, current);
    if (!mounted || picked == null) return;
    final state = ref.read(albumSearchControllerProvider);
    final controller = ref.read(albumSearchControllerProvider.notifier);
    if (state.subject.isNotEmpty && _text.text.trim().isEmpty) {
      await controller.setFilters(picked);
    } else {
      await controller.search(_text.text, filters: picked);
    }
  }

  Future<void> _setDeleted(List<MediaAsset> selected, bool deleted) async {
    final ids = [
      for (final asset in selected)
        if (asset.isDeleted != deleted) asset.id,
    ];
    if (deleted && !await confirmAlbumDeletion(context, ids.length)) return;
    if (!mounted) return;
    await _submit(
      (actions) => actions.setDeleted(ids, deleted),
      deleted ? '已标记待删除，可在「含待删除」中恢复' : '已恢复 ${ids.length} 项',
    );
  }

  Future<void> _bundle(List<MediaAsset> selected) async {
    final bundle = await showAlbumBundleDialog(context, selected);
    if (!mounted || bundle == null) return;
    await _submit(
      (actions) => actions.bundle(bundle.leadId, bundle.memberIds),
      '已捆绑所选媒体',
    );
  }

  Future<void> _unbundle(List<MediaAsset> selected) => _submit(
    (actions) => actions.unbundle([
      for (final asset in selected)
        if (asset.isGroupMember) asset.id,
    ]),
    '已解绑所选成员',
  );

  Future<void> _submit(
    Future<void> Function(AlbumActions) action,
    String success,
  ) async {
    var message = success;
    try {
      await action(ref.read(albumActionsProvider.notifier));
      if (mounted) _clearSelection();
    } catch (error) {
      message = '操作失败：$error';
    }
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 72),
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }
}
