import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/gallery/models/tag.dart';
import 'package:torrid/features/others/gallery/providers/gallery_providers.dart';

/// 拖拽打标签浮层
///
/// 交互（由底部"标签"按钮的 GestureDetector 驱动，本组件只响应其回调）：
///  1. 手指按住底部"标签"按钮并**向上拖动** → 浮层从底部弹出；
///  2. 手指滑到某个标签行上 → 高亮该行；悬停有子级的标签 350ms 自动展开下一级；
///  3. 手指接近面板上/下边缘 → 列表自动滚动，露出屏幕外的标签；
///  4. 松手在标签行上 → 添加/移除该标签（已有标签则移除，未打则添加）；
///  5. 拖到**右上角取消区**松手 → 不生效，关闭浮层。
///
/// 非向上拖动（误触/横向滑动）不会激活浮层，保持与"点击打开标签管理页"互不干扰。
class TagDragOverlay extends ConsumerStatefulWidget {
  /// 面板底部需要避让的高度（底部标签栏 + 导航栏 + 安全区），由 GalleryPage 传入
  final double bottomInset;

  const TagDragOverlay({super.key, required this.bottomInset});

  @override
  ConsumerState<TagDragOverlay> createState() => TagDragOverlayState();
}

class TagDragOverlayState extends ConsumerState<TagDragOverlay> {
  // ============ 拖拽会话状态 ============

  /// 是否已激活浮层（向上拖动确认后才为 true）
  bool _active = false;

  /// 已开始拖动但尚未确认方向（用于过滤误触）
  bool _pending = false;
  Offset? _pendingStart;

  /// 手指当前全局坐标（同步镜像到 [_dragPosNotifier] 供跟随组件无重建刷新）
  Offset _dragPos = Offset.zero;
  final ValueNotifier<Offset> _dragPosNotifier = ValueNotifier<Offset>(Offset.zero);

  /// 当前命中的标签 id
  String? _hoveredTagId;

  /// 本次会话中已展开的标签 id（悬停展开后保持，便于继续拖入子级）
  final Set<String> _expandedIds = {};

  // ============ 定时器 ============

  Timer? _expandTimer;
  String? _pendingExpandTagId;
  Timer? _scrollTimer;
  double _scrollSpeed = 0;

  // ============ 布局定位 ============

  /// 标签行 GlobalKey（随滚动/展开实时变化）
  final Map<String, GlobalKey> _rowKeys = {};
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _panelKey = GlobalKey();

  /// 面板可视区域（全局坐标），用于命中边界与边缘自动滚动
  Rect? _panelRect;

  /// 右上角取消区（全局坐标）
  Rect? _cancelZoneRect;

  static const double _edge = 56; // 自动滚动触发边缘宽度
  static const int _expandDelay = 350; // 悬停展开延迟 (ms)

  @override
  void dispose() {
    _expandTimer?.cancel();
    _scrollTimer?.cancel();
    _dragPosNotifier.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ============ 对外手势入口（GalleryPage 调用） ============

  /// 按下并拖动开始（先不激活，等待确认向上）
  void startDrag(Offset globalPos) {
    _pending = true;
    _pendingStart = globalPos;
  }

  /// 拖动更新
  void updateDrag(Offset globalPos) {
    if (!_active) {
      // 尚未激活：仅当明显向上拖动时激活，否则静默丢弃（防误触）
      if (_pending && _pendingStart != null) {
        final d = globalPos - _pendingStart!;
        if (d.dy <= -14) {
          _activate(globalPos);
        } else if (d.dy >= 14 || (d.dx.abs() > 48 && d.dy > -14)) {
          _pending = false;
        }
      }
      return;
    }
    _dragPos = globalPos;
    _dragPosNotifier.value = globalPos;
    _updateHover(globalPos);
    _updateAutoScroll(globalPos);
  }

  /// 松手：命中标签则切换，命中取消区则放弃
  Future<void> endDrag(Offset globalPos) async {
    if (!_active) {
      _pending = false;
      return;
    }
    _stopAutoScroll();
    _expandTimer?.cancel();

    final inCancel = _cancelZoneRect?.contains(globalPos) ?? false;
    final targetTagId = inCancel ? null : _hitTestTag(globalPos);

    setState(() {
      _active = false;
      _hoveredTagId = null;
    });

    if (targetTagId != null) {
      HapticFeedback.mediumImpact();
      final tag = _findTag(targetTagId);
      final applied = _appliedTagIds.contains(targetTagId);
      final notifier = ref.read(currentMediaTagsProvider.notifier);
      try {
        if (applied) {
          await notifier.removeTag(targetTagId);
          if (mounted && tag != null) _toast('已移除标签「${tag.name}」');
        } else {
          await notifier.addTag(targetTagId);
          if (mounted && tag != null) _toast('已添加标签「${tag.name}」');
        }
      } catch (e) {
        if (mounted) _toast('操作失败: $e');
      }
    } else if (inCancel) {
      if (mounted) _toast('已取消拖拽');
    }
  }

  /// 手势被系统取消（来电等）
  void cancelDrag() {
    _pending = false;
    _stopAutoScroll();
    _expandTimer?.cancel();
    if (mounted) {
      setState(() {
        _active = false;
        _hoveredTagId = null;
      });
    }
  }

  // ============ 激活/内部逻辑 ============

  void _activate(Offset globalPos) {
    _pending = false;
    _expandTimer?.cancel();
    _stopAutoScroll();
    setState(() {
      _active = true;
      _dragPos = globalPos;
      _dragPosNotifier.value = globalPos;
      _hoveredTagId = null;
      _pendingExpandTagId = null;
      _expandedIds.clear();
      _rowKeys.clear();
    });
    HapticFeedback.selectionClick();
    _refreshLayout();
    _updateHover(globalPos);
  }

  List<Tag> get _allTags => ref.read(tagTreeProvider).valueOrNull ?? [];

  Set<String> get _appliedTagIds => (ref
          .read(currentMediaTagsProvider)
          .valueOrNull ??
      const <Tag>[])
      .map((t) => t.id)
      .toSet();

  Tag? _findTag(String id) {
    for (final t in _allTags) {
      if (t.id == id) return t;
    }
    return null;
  }

  List<Tag> _childrenOf(String id) =>
      _allTags.where((t) => t.parentId == id).toList();

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(milliseconds: 1200),
    ));
  }

  /// 布局变化后重新采集面板/取消区全局矩形（首帧与展开后调用）
  void _refreshLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_active) return;
      final box = _panelKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.attached) {
        _panelRect = box.localToGlobal(Offset.zero) & box.size;
      }
      final size = MediaQuery.of(context).size;
      final topPad = MediaQuery.of(context).padding.top;
      _cancelZoneRect = Rect.fromCircle(
        center: Offset(size.width - 62, topPad + 62),
        radius: 48,
      );
    });
  }

  /// 命中测试：返回手指当前所在的最深标签 id，无则 null
  String? _hitTestTag(Offset globalPos) {
    final panel = _panelRect;
    if (panel == null || !panel.contains(globalPos)) return null;

    // 倒序遍历：后插入的行（更深层子级）优先命中
    final entries = _rowKeys.entries.toList().reversed;
    for (final entry in entries) {
      final box = entry.value.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.contains(globalPos)) return entry.key;
    }
    return null;
  }

  /// 更新悬停高亮 + 悬停展开
  void _updateHover(Offset globalPos) {
    if (!_active) return;
    final inCancel = _cancelZoneRect?.contains(globalPos) ?? false;
    final tagId = inCancel ? null : _hitTestTag(globalPos);

    if (tagId != _hoveredTagId) {
      setState(() => _hoveredTagId = tagId);
    }

    // 悬停展开：手指停留在有子级且未展开的标签上，延迟后展开
    _expandTimer?.cancel();
    _pendingExpandTagId = null;
    if (tagId != null && !_expandedIds.contains(tagId)) {
      final children = _childrenOf(tagId);
      if (children.isNotEmpty) {
        _pendingExpandTagId = tagId;
        _expandTimer = Timer(const Duration(milliseconds: _expandDelay), () {
          if (!mounted || !_active) return;
          final pid = _pendingExpandTagId;
          if (pid == null) return;
          setState(() => _expandedIds.add(pid));
          _refreshLayout();
          // 展开后子级可能覆盖原位置，重新命中一次
          _updateHover(_dragPos);
        });
      }
    }
  }

  // ============ 边缘自动滚动 ============

  void _updateAutoScroll(Offset globalPos) {
    final panel = _panelRect;
    if (panel == null || globalPos.dx < panel.left || globalPos.dx > panel.right) {
      _stopAutoScroll();
      return;
    }

    double speed = 0;
    if (globalPos.dy < panel.top + _edge) {
      final ratio = (1 - (globalPos.dy - panel.top) / _edge)
          .clamp(0.0, 1.0)
          .toDouble();
      speed = -ratio * 14; // 向上
    } else if (globalPos.dy > panel.bottom - _edge) {
      final ratio = (1 - (panel.bottom - globalPos.dy) / _edge)
          .clamp(0.0, 1.0)
          .toDouble();
      speed = ratio * 14; // 向下
    }

    if (speed == 0) {
      _stopAutoScroll();
      return;
    }
    _scrollSpeed = speed;
    _scrollTimer ??= Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _tickScroll(),
    );
  }

  void _tickScroll() {
    if (!mounted || !_active || !_scrollController.hasClients) {
      _stopAutoScroll();
      return;
    }
    final pos = _scrollController.position;
    final next = (_scrollController.offset + _scrollSpeed)
        .clamp(pos.minScrollExtent, pos.maxScrollExtent)
        .toDouble();
    if ((next - _scrollController.offset).abs() < 0.01) {
      _stopAutoScroll();
      return;
    }
    _scrollController.jumpTo(next);
    // 行随滚动移动，重新命中
    _updateHover(_dragPos);
  }

  void _stopAutoScroll() {
    _scrollTimer?.cancel();
    _scrollTimer = null;
    _scrollSpeed = 0;
  }

  // ============ 渲染 ============

  @override
  Widget build(BuildContext context) {
    if (!_active) return const SizedBox.shrink();

    final tagsAsync = ref.watch(tagTreeProvider);
    final allTags = tagsAsync.valueOrNull ?? const <Tag>[];
    final appliedTags = ref.watch(currentMediaTagsProvider);
    final appliedIds = (appliedTags.valueOrNull ?? const <Tag>[])
        .map((t) => t.id)
        .toSet();
    final hoveredTag = _hoveredTagId == null ? null : _findTag(_hoveredTagId!);

    final size = MediaQuery.of(context).size;
    final topPad = MediaQuery.of(context).padding.top;

    // 构建树：按 fullPath 排序保证稳定显示
    final childrenMap = <String, List<Tag>>{};
    for (final t in allTags) {
      if (t.parentId != null) {
        childrenMap.putIfAbsent(t.parentId!, () => []).add(t);
      }
    }
    for (final list in childrenMap.values) {
      list.sort((a, b) => (a.fullPath ?? a.name).compareTo(b.fullPath ?? b.name));
    }
    final roots = allTags.where((t) => t.parentId == null).toList()
      ..sort((a, b) => (a.fullPath ?? a.name).compareTo(b.fullPath ?? b.name));

    return Stack(
      children: [
        // 半透明遮罩：吸收点击，避免拖动期间误触媒体区
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: Container(color: Colors.black38),
          ),
        ),

        // 右上角取消区（仅随手指位置局部刷新）
        Positioned(
          top: topPad + 12,
          right: 12,
          child: ValueListenableBuilder<Offset>(
            valueListenable: _dragPosNotifier,
            builder: (context, pos, _) {
              final inCancel = _cancelZoneRect?.contains(pos) ?? false;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: inCancel
                      ? Colors.red.withValues(alpha: 0.85)
                      : Colors.white.withValues(alpha: 0.12),
                  border: Border.all(
                    color: inCancel ? Colors.white : Colors.white38,
                    width: inCancel ? 2 : 1,
                  ),
                ),
                child: Icon(
                  Icons.close,
                  color: inCancel ? Colors.white : Colors.white70,
                  size: 30,
                ),
              );
            },
          ),
        ),

        // 标签面板
        Positioned(
          left: 0,
          right: 0,
          bottom: widget.bottomInset,
          height: (size.height * 0.55).clamp(200.0, 480.0).toDouble(),
          child: Container(
            key: _panelKey,
            decoration: BoxDecoration(
              color: const Color(0xF21E1E24),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 顶部指示条
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.white30,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                // 提示文字
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '松手 = 添加/移除标签 · 悬停父标签可展开 · 右上角 = 取消',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 6),
                // 标签列表
                Expanded(
                  child: allTags.isEmpty
                      ? Center(
                          child: Text(
                            tagsAsync.isLoading ? '标签加载中…' : '暂无标签',
                            style: const TextStyle(color: Colors.white38),
                          ),
                        )
                      : ListView(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(bottom: 12),
                          children: [
                            for (final root in roots)
                              _buildRow(
                                root,
                                childrenMap,
                                0,
                                appliedIds,
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),

        // 拖拽跟随指示条（仅该组件随手指刷新，避免每帧重建整个标签树）
        ValueListenableBuilder<Offset>(
          valueListenable: _dragPosNotifier,
          builder: (context, pos, _) {
            final inCancel = _cancelZoneRect?.contains(pos) ?? false;
            return Positioned(
              left: (pos.dx + 14).clamp(0.0, size.width - 170).toDouble(),
              top: (pos.dy - 26).clamp(topPad, size.height - 100).toDouble(),
              child: IgnorePointer(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white38),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        inCancel ? Icons.close : Icons.label,
                        size: 16,
                        color: inCancel ? Colors.redAccent : Colors.amber,
                      ),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: Text(
                          inCancel
                              ? '取消'
                              : hoveredTag != null
                                  ? '添加到「${hoveredTag.name}」'
                                  : '拖动到标签上',
                          style:
                              const TextStyle(color: Colors.white, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// 递归构建标签行（只展开 `_expandedIds` 中的子级）
  Widget _buildRow(
    Tag tag,
    Map<String, List<Tag>> childrenMap,
    int depth,
    Set<String> appliedIds,
  ) {
    final key = _rowKeys[tag.id] ??= GlobalKey();
    final children = childrenMap[tag.id] ?? const <Tag>[];
    final hasChildren = children.isNotEmpty;
    final expanded = _expandedIds.contains(tag.id);
    final hovered = _hoveredTagId == tag.id;
    final applied = appliedIds.contains(tag.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          key: key,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: EdgeInsets.only(
            left: 12.0 + depth * 20,
            right: 8,
            top: 6,
            bottom: 6,
          ),
          decoration: BoxDecoration(
            color: hovered
                ? (applied
                    ? Colors.orange.withValues(alpha: 0.4)
                    : Colors.blue.withValues(alpha: 0.4))
                : (applied
                    ? Colors.blue.withValues(alpha: 0.15)
                    : Colors.white10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hovered ? Colors.white : Colors.white12,
              width: hovered ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                hasChildren
                    ? (expanded ? Icons.folder_open : Icons.folder)
                    : Icons.label,
                size: 18,
                color: applied ? Colors.amber : Colors.white70,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tag.name,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (applied)
                const Icon(Icons.check_circle, size: 16, color: Colors.amber),
              if (hasChildren)
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: Colors.white38,
                ),
            ],
          ),
        ),
        if (expanded && hasChildren)
          ...children.map(
            (c) => _buildRow(c, childrenMap, depth + 1, appliedIds),
          ),
      ],
    );
  }
}
