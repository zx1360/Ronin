import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/album/models/deletion_review.dart';
import 'package:torrid/features/album/providers/album_providers.dart';
import 'package:torrid/features/album/services/ai_api_service.dart';
import 'package:torrid/features/album/widgets/album_dialogs.dart';
import 'package:torrid/features/album/widgets/review_thumbnail.dart';
import 'package:torrid/features/gallery/models/media_asset.dart';
import 'package:torrid/features/gallery/services/gallery_api_service.dart';
import 'package:torrid/features/gallery/widgets/media_viewer_page.dart';

enum _ReviewKind { duplicates, candidates, kept }

class AlbumCleanupTab extends ConsumerStatefulWidget {
  const AlbumCleanupTab({super.key, required this.active});

  final bool active;

  @override
  ConsumerState<AlbumCleanupTab> createState() => _AlbumCleanupTabState();
}

class _AlbumCleanupTabState extends ConsumerState<AlbumCleanupTab>
    with AutomaticKeepAliveClientMixin {
  _ReviewKind _kind = _ReviewKind.duplicates;
  final _selected = <String>{};
  List<AlbumDuplicateGroup>? _groups;
  AlbumDuplicateGroup? _group;
  List<MediaAsset> _kept = [];
  List<DeletionCandidate> _candidates = [];
  AlbumCleanupResults? _scan;
  int _nextOffset = 0;
  bool _hasMore = false;
  bool _loading = false;
  bool _writing = false;
  Object? _error;
  String? _notice;
  CancelToken? _read;
  CancelToken? _previewRead;
  Timer? _poll;

  @override
  bool get wantKeepAlive => true;

  @override
  void didUpdateWidget(covariant AlbumCleanupTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active) {
      _read?.cancel();
      _previewRead?.cancel();
      _poll?.cancel();
      _loading = false;
    } else if (!oldWidget.active && _kind != _ReviewKind.duplicates) {
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _read?.cancel();
    _previewRead?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  void _choose(_ReviewKind kind) {
    _poll?.cancel();
    _read?.cancel();
    setState(() {
      _kind = kind;
      _group = null;
      _error = null;
      _notice = null;
      _loading = false;
      _selected.clear();
    });
    if (widget.active && kind != _ReviewKind.duplicates) unawaited(_load());
  }

  Future<void> _load({bool append = false, bool quiet = false}) async {
    _poll?.cancel();
    _read?.cancel();
    final token = _read = CancelToken();
    final kind = _kind;
    if (!quiet) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final api = ref.read(aiApiProvider);
    try {
      switch (kind) {
        case _ReviewKind.duplicates:
          final groups = await api.duplicates(token);
          if (!mounted || token.isCancelled) return;
          setState(() {
            _groups = groups;
            _group = null;
          });
        case _ReviewKind.kept:
          final kept = await api.keptMedia(token);
          if (!mounted || token.isCancelled) return;
          setState(() => _kept = kept);
        case _ReviewKind.candidates:
          final statusOnly =
              quiet && (_nextOffset > 30 || _selected.isNotEmpty);
          final scan = await api.cleanupResults(
            token,
            offset: append || statusOnly ? _nextOffset : 0,
            limit: statusOnly ? 1 : 30,
          );
          if (!mounted || token.isCancelled) return;
          setState(() {
            _scan = scan;
            if (!statusOnly) {
              _candidates = [
                ...{
                  if (append)
                    for (final item in _candidates) item.asset.id: item,
                  for (final item in scan.candidates) item.asset.id: item,
                }.values,
              ];
              _nextOffset = scan.nextOffset;
              _hasMore = scan.hasMore;
            }
          });
          if (widget.active &&
              !scan.paused &&
              scan.pending + scan.running > 0) {
            _poll = Timer(const Duration(seconds: 4), () => _load(quiet: true));
          }
      }
      if (mounted && !token.isCancelled) {
        final ids = switch (kind) {
          _ReviewKind.duplicates => _groups!.expand(
            (group) => group.media.map((asset) => asset.id),
          ),
          _ReviewKind.candidates => _candidates.map((item) => item.asset.id),
          _ReviewKind.kept => _kept.map((asset) => asset.id),
        };
        setState(() {
          _error = null;
          if (_selected.isNotEmpty) _selected.retainAll(ids);
        });
      }
    } catch (error) {
      if (mounted && !token.isCancelled) setState(() => _error = error);
    } finally {
      if (identical(_read, token)) {
        _read = null;
        if (mounted && !token.isCancelled) setState(() => _loading = false);
      }
    }
  }

  Future<void> _write(
    Future<String> Function() action, {
    List<String>? reviewed,
  }) async {
    if (_writing) return;
    setState(() {
      _writing = true;
      _loading = false;
      _notice = null;
    });
    _read?.cancel();
    _poll?.cancel();
    final api = ref.read(aiApiProvider);
    try {
      final message = await action();
      if (!mounted || !identical(api, ref.read(aiApiProvider))) return;
      final duplicateIds = _kind == _ReviewKind.duplicates ? reviewed : null;
      setState(() {
        _selected.clear();
        _notice = message;
        if (duplicateIds != null) _removeReviewedDuplicates(duplicateIds);
      });
      if (duplicateIds == null && widget.active) await _load();
    } catch (error) {
      if (mounted && identical(api, ref.read(aiApiProvider))) {
        setState(() => _notice = '$error');
        if (widget.active && _kind == _ReviewKind.candidates) {
          unawaited(_load(quiet: true));
        }
      }
    } finally {
      if (mounted) setState(() => _writing = false);
    }
  }

  void _removeReviewedDuplicates(List<String> ids) {
    final reviewed = ids.toSet();
    final remaining = <AlbumDuplicateGroup>[];
    for (final group in _groups ?? const <AlbumDuplicateGroup>[]) {
      if (!group.media.any((item) => reviewed.contains(item.id))) {
        remaining.add(group);
        continue;
      }
      final media = group.media
          .where((item) => !reviewed.contains(item.id))
          .toList();
      final updated = media.length < 2
          ? null
          : AlbumDuplicateGroup(group.distance, media);
      if (identical(group, _group)) _group = updated;
      if (updated != null) remaining.add(updated);
    }
    _groups = remaining;
  }

  Future<void> _deleteSelected() async {
    final ids = _selected.toList();
    final confirmed = await confirmAlbumDeletion(
      context,
      ids.length,
      onlySelected: true,
    );
    if (!confirmed || !mounted) return;
    await _write(() async {
      await ref
          .read(albumActionsProvider.notifier)
          .setDeleted(ids, true, onlySelected: true);
      return '已标记待删除 ${ids.length} 项';
    }, reviewed: ids);
  }

  Future<void> _keepSelected() {
    final ids = _selected.toList();
    final keep = _kind != _ReviewKind.kept;
    return _write(() async {
      await ref.read(aiApiProvider).keepMedia(ids, keep: keep);
      return keep ? '已保留 ${ids.length} 项' : '已恢复 ${ids.length} 项的推荐资格';
    }, reviewed: ids);
  }

  void _toggle(String id) => setState(() {
    if (!_selected.add(id)) _selected.remove(id);
  });

  void _open(List<MediaAsset> media, String id) {
    final index = media.indexWhere((asset) => asset.id == id);
    if (index < 0) {
      setState(() => _notice = '文件已不在相册结果中');
      return;
    }
    final reasons = {
      if (_kind == _ReviewKind.candidates)
        for (final item in _candidates) item.asset.id: item.reason,
    };
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MediaViewerPage(
          assets: media,
          initialIndex: index,
          review: true,
          subtitleBuilder: (asset) => reasons[asset.id],
          actions: (_, asset) => [
            StatefulBuilder(
              builder: (_, update) {
                final selected = _selected.contains(asset.id);
                return IconButton(
                  tooltip: selected ? '取消勾选' : '勾选文件',
                  icon: Icon(
                    selected ? Icons.check_box : Icons.check_box_outline_blank,
                  ),
                  onPressed: () {
                    if (!mounted) return;
                    _toggle(asset.id);
                    update(() {});
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDuplicates(List<DuplicateMedia> items, int index) async {
    if (_previewRead != null) return;
    final token = CancelToken();
    setState(() => _previewRead = token);
    final start = (index - 20).clamp(0, items.length);
    final ids = items.skip(start).take(41).map((item) => item.id).toList();
    try {
      final page = await ref
          .read(galleryApiProvider)
          .queryMedia(ids: ids, limit: ids.length, cancelToken: token);
      if (!mounted || token.isCancelled || !widget.active) return;
      final byId = {for (final asset in page.mediaAssets) asset.id: asset};
      _open([
        for (final id in ids)
          if (byId[id] case final asset?) asset,
      ], items[index].id);
    } catch (error) {
      if (mounted && !token.isCancelled) setState(() => _notice = '$error');
    } finally {
      if (mounted && identical(token, _previewRead)) {
        setState(() => _previewRead = null);
      }
    }
  }

  void _showGroup(AlbumDuplicateGroup? group) {
    _previewRead?.cancel();
    setState(() {
      _previewRead = null;
      _group = group;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.listen(aiApiProvider, (_, _) {
      _read?.cancel();
      _previewRead?.cancel();
      _poll?.cancel();
      setState(() {
        _groups = null;
        _kept = [];
        _candidates = [];
        _scan = null;
        _hasMore = false;
        _nextOffset = 0;
      });
      _choose(_kind);
    });
    final actionBusy = ref.watch(albumActionsProvider);
    final busy = _writing || _previewRead != null || actionBusy;
    return PopScope(
      canPop: !widget.active || _group == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && widget.active && _group != null) _showGroup(null);
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: SegmentedButton<_ReviewKind>(
              segments: const [
                ButtonSegment(
                  value: _ReviewKind.duplicates,
                  label: Text('近重复'),
                ),
                ButtonSegment(
                  value: _ReviewKind.candidates,
                  label: Text('低价值'),
                ),
                ButtonSegment(value: _ReviewKind.kept, label: Text('已保留')),
              ],
              selected: {_kind},
              onSelectionChanged: busy
                  ? null
                  : (values) => _choose(values.single),
            ),
          ),
          _toolbar(busy),
          if (_notice case final notice?)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
              child: Text(notice),
            ),
          if (_loading || _previewRead != null) const LinearProgressIndicator(),
          if (_error case final error?)
            ListTile(
              title: Text('$error'),
              trailing: TextButton(
                onPressed: _loading ? null : _load,
                child: const Text('重试'),
              ),
            ),
          Expanded(child: _results(busy)),
          if (_selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton(
                    onPressed: busy ? null : () => setState(_selected.clear),
                    child: Text('已选 ${_selected.length}'),
                  ),
                  OutlinedButton(
                    onPressed: busy ? null : _keepSelected,
                    child: Text(_kind == _ReviewKind.kept ? '恢复参与筛选' : '保留'),
                  ),
                  if (_kind != _ReviewKind.kept)
                    FilledButton.tonal(
                      onPressed: busy ? null : _deleteSelected,
                      child: const Text('标记待删除'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _toolbar(bool busy) {
    if (_group case final group?) {
      return ListTile(
        dense: true,
        leading: IconButton(
          tooltip: '返回近重复分组',
          onPressed: _writing ? null : () => _showGroup(null),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text('${group.media.length} 张近重复图片'),
        subtitle: Text('哈希差异最多 ${group.distance} 位'),
      );
    }
    final scan = _scan;
    final disabled = busy || _loading;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (_kind == _ReviewKind.duplicates)
            OutlinedButton.icon(
              onPressed: _loading
                  ? () {
                      _read?.cancel();
                      setState(() => _loading = false);
                    }
                  : disabled
                  ? null
                  : _load,
              icon: const Icon(Icons.compare_outlined),
              label: Text(
                _loading
                    ? '取消等待'
                    : _groups == null
                    ? '计算近重复'
                    : '重新计算',
              ),
            ),
          if (_kind == _ReviewKind.duplicates && _groups != null)
            Text('${_groups!.length} 组'),
          if (_kind == _ReviewKind.candidates) ...[
            PopupMenuButton<int>(
              enabled: !disabled && scan?.enabled == true,
              onSelected: (limit) => _write(() async {
                final count = await ref.read(aiApiProvider).scanCleanup(limit);
                return count > 0 ? '已加入筛选队列 $count 项' : '没有新的待筛选文件';
              }),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 50, child: Text('筛选 50 项')),
                PopupMenuItem(value: 100, child: Text('筛选 100 项')),
                PopupMenuItem(value: 500, child: Text('筛选 500 项')),
                PopupMenuItem(value: 0, child: Text('筛选全部未处理文件')),
              ],
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Text('开始筛选 ▾'),
              ),
            ),
            if (scan != null) ...[
              Text(
                '已处理 ${scan.done} · 队列 ${scan.pending + scan.running} · 失败 ${scan.failed}',
              ),
              if (!scan.enabled) const Text('服务端 AI 已关闭'),
              if (scan.enabled && scan.paused && scan.pending > 0)
                TextButton(
                  onPressed: disabled
                      ? null
                      : () => _write(() async {
                          await ref.read(aiApiProvider).resumeQueue();
                          return 'AI 队列已继续';
                        }),
                  child: const Text('继续 AI 队列'),
                ),
              if (scan.enabled && scan.failed > 0)
                TextButton(
                  onPressed: disabled
                      ? null
                      : () => _write(() async {
                          await ref.read(aiApiProvider).retryCleanup();
                          return '失败项目已重新入队';
                        }),
                  child: const Text('重试失败项目'),
                ),
            ],
          ],
          if (_kind != _ReviewKind.duplicates)
            IconButton(
              tooltip: '刷新',
              onPressed: disabled ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
    );
  }

  Widget _results(bool busy) {
    final kind = _kind;
    final group = _group;
    if (kind == _ReviewKind.duplicates && group == null) {
      final groups = _groups;
      if (groups == null || groups.isEmpty) {
        return Center(child: Text(groups == null ? '计算后可逐组对比相似图片' : '暂无近重复图片'));
      }
      return ListView.builder(
        key: const PageStorageKey('duplicate-groups'),
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        itemCount: groups.length,
        itemBuilder: (context, index) {
          final group = groups[index];
          return _DuplicateGroupTile(
            group: group,
            onOpen: busy ? null : () => _showGroup(group),
          );
        },
      );
    }
    final count =
        group?.media.length ??
        (kind == _ReviewKind.candidates ? _candidates.length : _kept.length);
    final more = kind == _ReviewKind.candidates && _hasMore;
    if (count == 0 && !more) {
      return Center(
        child: Text(
          kind == _ReviewKind.candidates ? '暂无低价值媒体建议' : '保留的文件会从两类推荐中排除',
        ),
      );
    }
    return CustomScrollView(
      key: PageStorageKey((kind, group?.media.first.id)),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 205,
              mainAxisExtent: 186,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: count,
            itemBuilder: (context, index) {
              final candidate = kind == _ReviewKind.candidates
                  ? _candidates[index]
                  : null;
              final asset =
                  candidate?.asset ?? (group == null ? _kept[index] : null);
              final id = asset?.id ?? group!.media[index].id;
              final path = asset?.filePath ?? group!.media[index].path;
              return _CleanupMediaCard(
                key: ValueKey(id),
                id: id,
                path: path,
                reason: candidate?.reason,
                selected: _selected.contains(id),
                onSelect: busy ? null : () => _toggle(id),
                onOpen: busy
                    ? null
                    : () {
                        if (group != null) {
                          unawaited(_openDuplicates(group.media, index));
                        } else {
                          _open(
                            kind == _ReviewKind.kept
                                ? _kept
                                : _candidates.map((row) => row.asset).toList(),
                            id,
                          );
                        }
                      },
              );
            },
          ),
        ),
        if (more)
          SliverToBoxAdapter(
            child: Center(
              child: TextButton(
                onPressed: busy || _loading ? null : () => _load(append: true),
                child: const Text('加载更多'),
              ),
            ),
          ),
      ],
    );
  }
}

class _DuplicateGroupTile extends StatelessWidget {
  const _DuplicateGroupTile({required this.group, required this.onOpen});

  final AlbumDuplicateGroup group;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card.outlined(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('${group.media.length} 张近重复图片')),
                  Text('差异最多 ${group.distance} 位'),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                spacing: 6,
                children: [
                  for (final item in group.media.take(3))
                    Expanded(
                      child: SizedBox(
                        height: 76,
                        child: ColoredBox(
                          color: colors.surfaceContainerHigh,
                          child: ReviewThumbnail(id: item.id),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CleanupMediaCard extends StatelessWidget {
  const _CleanupMediaCard({
    super.key,
    required this.id,
    required this.path,
    required this.reason,
    required this.selected,
    required this.onOpen,
    required this.onSelect,
  });

  final String id;
  final String path;
  final String? reason;
  final bool selected;
  final VoidCallback? onOpen;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card.outlined(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: selected ? colors.secondaryContainer : null,
      child: InkWell(
        onTap: onOpen,
        onLongPress: onSelect,
        child: Column(
          children: [
            Expanded(
              child: ColoredBox(
                color: colors.surfaceContainerHighest,
                child: SizedBox.expand(child: ReviewThumbnail(id: id)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mediaFileName(path),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (reason case final message?)
                          Text(
                            message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  Checkbox(
                    value: selected,
                    onChanged: onSelect == null ? null : (_) => onSelect!(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
