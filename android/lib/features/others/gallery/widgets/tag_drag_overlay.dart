import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/gallery/models/tag.dart';
import 'package:torrid/features/others/gallery/models/tag_tree.dart';
import 'package:torrid/features/others/gallery/providers/gallery_providers.dart';

/// 拖出后松手切换标签；长按入口可固定面板，连续点选。
class TagDragOverlay extends ConsumerStatefulWidget {
  final double bottomInset;
  final int quarterTurns;
  const TagDragOverlay({
    super.key,
    required this.bottomInset,
    this.quarterTurns = 0,
  });
  @override
  ConsumerState<TagDragOverlay> createState() => TagDragOverlayState();
}

class TagDragOverlayState extends ConsumerState<TagDragOverlay> {
  bool _visible = false, _pinned = false;
  Offset? _pendingStart;
  Offset _dragPos = Offset.zero;
  final _dragPosition = ValueNotifier(Offset.zero);
  String? _hoveredTagId, _hoveredFavoriteId;
  final Set<String> _expandedIds = {};
  Timer? _expandTimer, _scrollTimer;
  double _scrollSpeed = 0;
  ScrollController? _scrollTarget;
  final _treeScroll = ScrollController(), _favoriteScroll = ScrollController();
  final _rootKey = GlobalKey(), _cancelKey = GlobalKey();
  final _treeViewportKey = GlobalKey(), _favoriteViewportKey = GlobalKey();
  final Map<String, GlobalKey> _rowKeys = {}, _favoriteKeys = {};

  @override
  void dispose() {
    _expandTimer?.cancel();
    _scrollTimer?.cancel();
    _dragPosition.dispose();
    _treeScroll.dispose();
    _favoriteScroll.dispose();
    super.dispose();
  }

  RenderBox? get _rootBox {
    final box = _rootKey.currentContext?.findRenderObject() as RenderBox?;
    return box != null && box.attached && box.hasSize ? box : null;
  }

  Offset _toLocal(Offset global) => _rootBox?.globalToLocal(global) ?? global;

  Rect? _rectOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    final root = _rootBox;
    if (box == null || !box.attached || !box.hasSize || root == null) {
      return null;
    }
    return Rect.fromPoints(
      root.globalToLocal(box.localToGlobal(Offset.zero)),
      root.globalToLocal(box.localToGlobal(box.size.bottomRight(Offset.zero))),
    );
  }

  bool _inCancel(Offset local) => _rectOf(_cancelKey)?.contains(local) ?? false;

  void startDrag(Offset globalPos) {
    if (!_pinned) _pendingStart = globalPos;
  }

  void updateDrag(Offset globalPos) {
    if (_pinned) return;
    if (!_visible) {
      final start = _pendingStart;
      if (start == null) return;
      final delta = globalPos - start;
      if (widget.quarterTurns % 4 != 0
          ? delta.distance >= 14
          : delta.dy <= -14) {
        _pendingStart = null;
        _rowKeys.clear();
        _favoriteKeys.clear();
        _expandedIds.clear();
        HapticFeedback.selectionClick();
        setState(() => _visible = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _visible && !_pinned) _move(globalPos);
        });
      } else if (delta.dy > 14 || delta.dx.abs() > 48) {
        _pendingStart = null;
      }
      return;
    }
    _move(globalPos);
  }

  void _move(Offset globalPos) {
    _dragPos = _toLocal(globalPos);
    _dragPosition.value = _dragPos;
    _updateHover();
    _updateAutoScroll();
  }

  Future<void> endDrag(Offset globalPos) async {
    _pendingStart = null;
    if (_pinned || !_visible) return;
    final local = _toLocal(globalPos);
    final id = _inCancel(local) ? null : _hitFavorite(local) ?? _hitRow(local);
    close();
    if (id != null) await _toggleTag(id);
  }

  void cancelDrag() {
    _pendingStart = null;
    if (!_pinned) close();
  }

  void openPinned() {
    _pendingStart = null;
    _stopAutoScroll();
    _expandTimer?.cancel();
    HapticFeedback.selectionClick();
    setState(() {
      _visible = _pinned = true;
      _hoveredTagId = _hoveredFavoriteId = null;
    });
  }

  void close() {
    _stopAutoScroll();
    _expandTimer?.cancel();
    _pendingStart = null;
    if (!_visible) return;
    setState(() {
      _visible = _pinned = false;
      _hoveredTagId = _hoveredFavoriteId = null;
    });
  }

  Future<void> _toggleTag(String id) async {
    HapticFeedback.selectionClick();
    try {
      await ref.read(currentMediaTagsProvider.notifier).toggleTag(id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('操作失败: $e')));
      }
    }
  }

  String? _hitRow(Offset local) => _hitIn(_rowKeys, _treeViewportKey, local);
  String? _hitFavorite(Offset local) =>
      _hitIn(_favoriteKeys, _favoriteViewportKey, local);

  String? _hitIn(
    Map<String, GlobalKey> keys,
    GlobalKey viewport,
    Offset local,
  ) {
    if (!(_rectOf(viewport)?.contains(local) ?? false)) return null;
    for (final entry in keys.entries) {
      if (_rectOf(entry.value)?.contains(local) ?? false) return entry.key;
    }
    return null;
  }

  void _updateHover() {
    if (!_visible || _pinned) return;
    final favoriteId = _inCancel(_dragPos) ? null : _hitFavorite(_dragPos);
    final tagId = _inCancel(_dragPos) || favoriteId != null
        ? null
        : _hitRow(_dragPos);
    if (tagId == _hoveredTagId && favoriteId == _hoveredFavoriteId) return;
    _expandTimer?.cancel();
    setState(() {
      _hoveredTagId = tagId;
      _hoveredFavoriteId = favoriteId;
    });
    final tags = ref.read(tagTreeProvider).valueOrNull ?? const <Tag>[];
    if (tagId != null &&
        !_expandedIds.contains(tagId) &&
        tags.any((t) => t.parentId == tagId)) {
      _expandTimer = Timer(const Duration(milliseconds: 280), () {
        if (!mounted || !_visible || _pinned || _hoveredTagId != tagId) return;
        setState(() => _expandedIds.add(tagId));
        _refreshHitAfterLayout();
      });
    }
  }

  void _refreshHitAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _visible && !_pinned) _updateHover();
    });
  }

  void _updateAutoScroll() {
    final favorite = _rectOf(_favoriteViewportKey);
    final tree = _rectOf(_treeViewportKey);
    final useFavorite = favorite?.contains(_dragPos) ?? false;
    final viewport = useFavorite ? favorite : tree;
    if (viewport == null ||
        !viewport.contains(_dragPos) ||
        _inCancel(_dragPos)) {
      _stopAutoScroll();
      return;
    }
    _scrollTarget = useFavorite ? _favoriteScroll : _treeScroll;
    final edge = math.min(48.0, viewport.height / 4);
    _scrollSpeed = _dragPos.dy < viewport.top + edge
        ? -12 * (1 - (_dragPos.dy - viewport.top) / edge)
        : _dragPos.dy > viewport.bottom - edge
        ? 12 * (1 - (viewport.bottom - _dragPos.dy) / edge)
        : 0;
    if (_scrollSpeed == 0) {
      _stopAutoScroll();
      return;
    }
    _scrollTimer ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
      final scroll = _scrollTarget;
      if (!mounted ||
          !_visible ||
          _pinned ||
          scroll == null ||
          !scroll.hasClients) {
        _stopAutoScroll();
        return;
      }
      final next = (scroll.offset + _scrollSpeed).clamp(
        0.0,
        scroll.position.maxScrollExtent,
      );
      if ((next - scroll.offset).abs() < 0.01) {
        _stopAutoScroll();
        return;
      }
      scroll.jumpTo(next);
      _refreshHitAfterLayout();
    });
  }

  void _stopAutoScroll() {
    _scrollTimer?.cancel();
    _scrollTimer = null;
    _scrollTarget = null;
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final tags = ref.watch(tagTreeProvider).valueOrNull ?? const <Tag>[];
    final applied =
        (ref.watch(currentMediaTagsProvider).valueOrNull ?? const <Tag>[])
            .map((t) => t.id)
            .toSet();
    final favorites = ref.watch(favoriteTagsProvider);
    final children = groupTagsByParent(tags);
    final nodes = flattenTagTree(children, expanded: _expandedIds);
    final turns = widget.quarterTurns % 4;
    final safeTop = MediaQuery.paddingOf(context).top + 8;
    final controls = widget.bottomInset + 8;
    final insets = switch (turns) {
      1 => EdgeInsets.fromLTRB(safeTop, 8, controls, 8),
      2 => EdgeInsets.fromLTRB(8, controls, 8, safeTop),
      3 => EdgeInsets.fromLTRB(controls, 8, safeTop, 8),
      _ => EdgeInsets.fromLTRB(8, safeTop, 8, controls),
    };
    return RotatedBox(
      quarterTurns: turns,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final available = math.max(0.0, size.height - insets.vertical);
          final height = size.width > size.height
              ? available
              : math.min(available, size.height * 0.68);
          return Stack(
            key: _rootKey,
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _pinned ? close : () {},
                  child: ColoredBox(
                    color: _pinned ? Colors.black54 : Colors.black38,
                  ),
                ),
              ),
              Positioned(
                left: insets.left,
                right: insets.right,
                bottom: insets.bottom,
                height: height,
                child: Material(
                  color: const Color(0xF21E1E24),
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      _header(tags, applied.length),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: SizedBox(
                                key: _treeViewportKey,
                                child: nodes.isEmpty
                                    ? const Center(
                                        child: Text(
                                          '暂无标签',
                                          style: TextStyle(
                                            color: Colors.white54,
                                          ),
                                        ),
                                      )
                                    : LayoutBuilder(
                                        builder: (_, box) => GridView.builder(
                                          controller: _treeScroll,
                                          padding: const EdgeInsets.fromLTRB(
                                            4,
                                            0,
                                            4,
                                            8,
                                          ),
                                          gridDelegate:
                                              SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount:
                                                    (box.maxWidth / 240)
                                                        .floor()
                                                        .clamp(1, 3),
                                                mainAxisExtent: 44,
                                              ),
                                          itemCount: nodes.length,
                                          itemBuilder: (_, index) {
                                            final node = nodes[index];
                                            final tag = node.tag;
                                            return _TagTile(
                                              key: _rowKeys[tag.id] ??=
                                                  GlobalKey(),
                                              tag: tag,
                                              depth: node.depth,
                                              hasChildren: node.hasChildren,
                                              expanded: _expandedIds.contains(
                                                tag.id,
                                              ),
                                              applied: applied.contains(tag.id),
                                              hovered: _hoveredTagId == tag.id,
                                              onTap: _pinned
                                                  ? () => _toggleTag(tag.id)
                                                  : null,
                                              onExpand:
                                                  _pinned && node.hasChildren
                                                  ? () => setState(() {
                                                      if (!_expandedIds.remove(
                                                        tag.id,
                                                      )) {
                                                        _expandedIds.add(
                                                          tag.id,
                                                        );
                                                      }
                                                    })
                                                  : null,
                                            );
                                          },
                                        ),
                                      ),
                              ),
                            ),
                            if (favorites.isNotEmpty) ...[
                              const VerticalDivider(
                                width: 1,
                                color: Colors.white24,
                              ),
                              SizedBox(
                                key: _favoriteViewportKey,
                                width: math.min(
                                  172,
                                  (size.width - insets.horizontal) * 0.27,
                                ),
                                child: ListView.builder(
                                  controller: _favoriteScroll,
                                  itemExtent: 44,
                                  padding: const EdgeInsets.fromLTRB(
                                    4,
                                    0,
                                    4,
                                    8,
                                  ),
                                  itemCount: favorites.length,
                                  itemBuilder: (_, index) {
                                    final tag = favorites[index];
                                    return _TagTile(
                                      key: _favoriteKeys[tag.id] ??=
                                          GlobalKey(),
                                      tag: tag,
                                      favorite: true,
                                      applied: applied.contains(tag.id),
                                      hovered: _hoveredFavoriteId == tag.id,
                                      onTap: _pinned
                                          ? () => _toggleTag(tag.id)
                                          : null,
                                      onLongPress: _pinned
                                          ? () => _favoriteMenu(tag)
                                          : null,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!_pinned)
                ValueListenableBuilder<Offset>(
                  valueListenable: _dragPosition,
                  builder: (_, pos, _) => _indicator(pos, size, tags, applied),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _header(List<Tag> tags, int count) {
    final parents = {
      for (final t in tags)
        if (t.parentId != null) t.parentId!,
    };
    final allExpanded = parents.isNotEmpty && _expandedIds.containsAll(parents);
    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Row(
          children: [
            const Text(
              '快速打标签',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _pinned ? '已选 $count · 点击切换' : '松手切换 · 停留展开',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ),
            if (_pinned && parents.isNotEmpty)
              IconButton(
                tooltip: allExpanded ? '全部收起' : '全部展开',
                icon: Icon(
                  allExpanded ? Icons.unfold_less : Icons.unfold_more,
                  color: Colors.white70,
                  size: 20,
                ),
                onPressed: () => setState(() {
                  if (allExpanded) {
                    _expandedIds.clear();
                  } else {
                    _expandedIds.addAll(parents);
                  }
                }),
              ),
            SizedBox(
              key: _cancelKey,
              width: 48,
              height: 44,
              child: IconButton(
                tooltip: _pinned ? '关闭' : '松手取消',
                onPressed: close,
                icon: const Icon(Icons.close, color: Colors.white70, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _indicator(
    Offset pos,
    Size size,
    List<Tag> tags,
    Set<String> applied,
  ) {
    final id = _hoveredFavoriteId ?? _hoveredTagId;
    final target = tags.where((t) => t.id == id).firstOrNull;
    final cancel = _inCancel(pos);
    final action = applied.contains(id) ? '移除' : '添加';
    final label = cancel
        ? '松手取消'
        : target == null
        ? '拖到标签上，松手切换'
        : '$action「${target.fullPath ?? target.name}」';
    return Positioned(
      left: (pos.dx - 90).clamp(0.0, math.max(0.0, size.width - 190)),
      top: (pos.dy - 64).clamp(0.0, math.max(0.0, size.height - 40)),
      child: IgnorePointer(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 190),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: cancel ? Colors.redAccent : Colors.white38,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cancel ? Colors.redAccent : Colors.amber,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _favoriteMenu(Tag tag) async {
    final remove = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.star_border),
          title: const Text('移出快捷标签'),
          subtitle: Text(tag.fullPath ?? tag.name),
          onTap: () => Navigator.pop(ctx, true),
        ),
      ),
    );
    if (remove != true || !mounted) return;
    try {
      await ref.read(tagTreeProvider.notifier).setFavorite(tag.id, false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('快捷标签更新失败: $e')));
      }
    }
  }
}

class _TagTile extends StatelessWidget {
  final Tag tag;
  final int depth;
  final bool hasChildren, expanded, applied, hovered, favorite;
  final VoidCallback? onTap, onExpand, onLongPress;
  const _TagTile({
    super.key,
    required this.tag,
    required this.applied,
    required this.hovered,
    this.depth = 0,
    this.hasChildren = false,
    this.expanded = false,
    this.favorite = false,
    this.onTap,
    this.onExpand,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tag.fullPath ?? tag.name,
    child: Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: hovered
            ? (applied ? Colors.orange.shade800 : Colors.blue.shade700)
            : applied
            ? const Color(0xFF253C51)
            : Colors.white10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: hovered ? Colors.white : Colors.white12),
        ),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.only(
              left: 8 + math.min(depth, 3) * 8,
              right: 6,
            ),
            child: Row(
              children: [
                Icon(
                  favorite
                      ? Icons.star
                      : hasChildren
                      ? (expanded ? Icons.folder_open : Icons.folder)
                      : Icons.label,
                  size: 16,
                  color: applied || favorite ? Colors.amber : Colors.white70,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    tag.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
                if (applied)
                  const Icon(Icons.check, size: 16, color: Colors.amber),
                if (hasChildren)
                  SizedBox(
                    width: 32,
                    height: 40,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: onExpand,
                      icon: Icon(
                        expanded ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                        color: Colors.white70,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
