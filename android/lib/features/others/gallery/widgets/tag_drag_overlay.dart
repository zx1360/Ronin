import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/gallery/models/tag.dart';
import 'package:torrid/features/others/gallery/providers/gallery_providers.dart';

/// 快速打标签浮层
///
/// 两种使用方式:
/// 1. **拖拽模式**: 按住底部"标签"按钮向上拖动弹出浮层, 手指滑过标签行
///    (左侧标签树 / 右侧快捷标签) 即高亮, 松手即添加/移除; 经过有子级的标签
///    立即展开下一级; 拖到右上角取消区松手则放弃本次操作.
/// 2. **固定模式**: 长按底部"标签"按钮使浮层常驻, 可直接点击标签切换,
///    并可在浮层内管理右侧快捷标签.
///
/// 浮层所有几何信息(面板、取消区、行位置)均在需要时实时读取, 因此设备旋转、
/// 媒体旋转或任何尺寸变化后都不会出现命中错位.
///
/// 浮层会随 [quarterTurns]（媒体查看时的旋转方向）一起旋转：媒体转成横向后，
/// 打标签的面板也贴在"媒体的底边"、文字方向与媒体一致，不必来回转手机。
/// 旋转后一切坐标以浮层自身坐标系为准（手指的屏幕坐标先换算进来），
/// 因此命中判定与拖拽指示器在两种方向下都准确。
class TagDragOverlay extends ConsumerStatefulWidget {
  /// 面板底部需要避让的高度（底部标签栏 + 导航栏 + 安全区），由 GalleryPage 传入
  final double bottomInset;

  /// 媒体当前旋转的四分之一圈数（0 = 未旋转）
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
  // 会话状态

  /// 浮层是否可见
  bool _visible = false;

  /// 是否固定模式（可交互）; false 为跟随手指的拖拽模式
  bool _pinned = false;

  /// 已按下但尚未确认方向（用于过滤误触）
  bool _pending = false;
  Offset? _pendingStart;

  /// 手指当前全局坐标（同步镜像到 [_dragPosNotifier] 供跟随组件无重建刷新）
  Offset _dragPos = Offset.zero;
  final ValueNotifier<Offset> _dragPosNotifier =
      ValueNotifier<Offset>(Offset.zero);

  /// 当前命中的标签 / 快捷标签
  String? _hoveredTagId;
  String? _hoveredFavoriteId;

  /// 本次会话中已展开的标签 id
  final Set<String> _expandedIds = {};

  // 自动滚动

  Timer? _scrollTimer;
  double _scrollSpeed = 0;
  ScrollController? _scrollTarget;

  // 布局定位

  final Map<String, GlobalKey> _rowKeys = {};
  final Map<String, GlobalKey> _favoriteKeys = {};
  final ScrollController _treeScroll = ScrollController();
  final ScrollController _favoriteScroll = ScrollController();
  final GlobalKey _panelKey = GlobalKey();
  final GlobalKey _favoriteColumnKey = GlobalKey();

  /// 浮层根节点：旋转后它自己的坐标系与屏幕坐标系不同，一切换算都经它进行
  final GlobalKey _rootKey = GlobalKey();

  /// 自动滚动触发边缘宽度
  static const double _edge = 56;

  /// 旋转帧内左上角的避让高度（旋转后屏幕矩形不再是"上面那一条"）
  static const double _rotatedTopInset = 12;

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _dragPosNotifier.dispose();
    _treeScroll.dispose();
    _favoriteScroll.dispose();
    super.dispose();
  }

  // 坐标换算（旋转后屏幕坐标 ≠ 浮层坐标）

  /// 浮层根节点；尚未完成布局时返回 null（构建期读它的大小会触发 hasSize 断言）。
  RenderBox? get _rootBox {
    final box = _rootKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return null;
    return box;
  }

  bool get _isRotated => widget.quarterTurns % 4 != 0;

  /// 浮层坐标系尺寸：优先用本帧布局结果（[LayoutBuilder] 已给），其次根节点。
  Size get _frameSize =>
      _frameSizeOverride ?? _rootBox?.size ?? MediaQuery.sizeOf(context);

  /// 本帧的浮层尺寸，由 [_buildStack] 在布局时写入（构建期根节点可能还没有尺寸）。
  Size? _frameSizeOverride;

  double get _frameTopInset =>
      _isRotated ? _rotatedTopInset : MediaQuery.paddingOf(context).top;

  /// 屏幕坐标 → 浮层坐标系。
  Offset _toLocal(Offset global) => _rootBox?.globalToLocal(global) ?? global;

  /// 取消区中心（浮层坐标系内，与绘制位置一致）
  Offset _cancelCenter(Size size) => Offset(size.width - 48, _frameTopInset + 48);

  // 对外入口（GalleryPage 调用）

  /// 按下并拖动开始（先不激活，等待确认方向）
  void startDrag(Offset globalPos) {
    if (_pinned) return;
    _pending = true;
    _pendingStart = _toLocal(globalPos);
  }

  /// 拖动更新
  void updateDrag(Offset globalPos) {
    if (_pinned) return;
    final local = _toLocal(globalPos);
    if (!_visible) {
      // 尚未激活：仅当明显朝面板方向拖动时激活，否则静默丢弃（防误触）
      final start = _pendingStart;
      if (_pending && start != null) {
        final d = local - start;
        if (_isRotated) {
          // 旋转后屏幕上的"上"不再对应面板方向（面板跟着媒体转到了侧边），
          // 只要位移足够明确就激活——松手没落到标签上不会有任何副作用。
          if (d.distance >= 14) _activate(globalPos);
        } else if (d.dy <= -14) {
          _activate(globalPos);
        } else if (d.dy >= 14 || (d.dx.abs() > 48 && d.dy > -14)) {
          _pending = false;
        }
      }
      return;
    }
    _dragPos = local;
    _dragPosNotifier.value = local;
    _updateHover(local);
    _updateAutoScroll(local);
  }

  /// 松手：命中标签则切换，命中取消区则放弃
  Future<void> endDrag(Offset globalPos) async {
    if (_pinned || !_visible) {
      _pending = false;
      return;
    }
    _stopAutoScroll();

    final local = _toLocal(globalPos);
    final inCancel = _cancelZoneRect.contains(local);
    final targetId =
        inCancel ? null : (_hitFavorite(local) ?? _hitRow(local));

    setState(() {
      _visible = false;
      _hoveredTagId = null;
      _hoveredFavoriteId = null;
    });
    _scrollTarget = null;

    if (targetId != null) await _toggleTag(targetId);
  }

  /// 手势被系统取消（来电等）
  void cancelDrag() {
    _pending = false;
    _stopAutoScroll();
    if (_visible && !_pinned) {
      setState(() {
        _visible = false;
        _hoveredTagId = null;
        _hoveredFavoriteId = null;
      });
    }
  }

  /// 打开常驻浮层（长按底部"标签"按钮）
  void openPinned() {
    if (_visible && _pinned) return;
    _pending = false;
    _stopAutoScroll();
    HapticFeedback.selectionClick();
    setState(() {
      _visible = true;
      _pinned = true;
      _hoveredTagId = null;
      _hoveredFavoriteId = null;
    });
  }

  /// 关闭浮层
  void close() {
    _stopAutoScroll();
    if (!_visible) return;
    setState(() {
      _visible = false;
      _pinned = false;
      _pending = false;
      _hoveredTagId = null;
      _hoveredFavoriteId = null;
    });
  }

  // 内部逻辑

  void _activate(Offset globalPos) {
    _pending = false;
    _stopAutoScroll();
    HapticFeedback.selectionClick();
    final local = _toLocal(globalPos);
    setState(() {
      _visible = true;
      _pinned = false;
      _dragPos = local;
      _hoveredTagId = null;
      _hoveredFavoriteId = null;
      _expandedIds.clear();
      _rowKeys.clear();
    });
    _dragPosNotifier.value = local;
    _updateHover(local);
  }

  List<Tag> get _allTags => ref.read(tagTreeProvider).valueOrNull ?? const [];

  Set<String> get _appliedTagIds => (ref
              .read(currentMediaTagsProvider)
              .valueOrNull ??
          const <Tag>[])
      .map((t) => t.id)
      .toSet();

  List<Tag> _childrenOf(String id) =>
      _allTags.where((t) => t.parentId == id).toList();

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(milliseconds: 1200),
    ));
  }

  /// 添加 / 移除标签
  Future<void> _toggleTag(String tagId) async {
    final applied = _appliedTagIds.contains(tagId);
    HapticFeedback.mediumImpact();
    final notifier = ref.read(currentMediaTagsProvider.notifier);
    try {
      if (applied) {
        await notifier.removeTag(tagId);
      } else {
        await notifier.addTag(tagId);
      }
    } catch (e) {
      _toast('操作失败: $e');
    }
  }

  /// 设置/取消快捷标签（服务端持久化）
  Future<void> _setFavorite(Tag tag, bool value) async {
    try {
      await ref.read(tagTreeProvider.notifier).setFavorite(tag.id, value);
    } catch (e) {
      _toast('快捷标签更新失败: $e');
    }
  }

  // 几何（全部实时读取，避免布局变化后失效）

  /// 命中区域换算到浮层坐标系：旋转后子节点与根节点共用同一变换，
  /// 用根节点做 globalToLocal 即可得到轴向对齐的矩形。
  Rect? _rectOf(GlobalKey key) {
    final root = _rootBox;
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (root == null || box == null || !box.attached) return null;
    return root.globalToLocal(box.localToGlobal(Offset.zero)) & box.size;
  }

  Rect? get _panelRect => _rectOf(_panelKey);

  /// 右上角取消区（浮层坐标系内；与绘制位置一致，半径略放大以便命中）
  Rect get _cancelZoneRect => Rect.fromCircle(
        center: _cancelCenter(_frameSize),
        radius: 48,
      );

  /// 命中测试：返回手指下的标签 id
  String? _hitRow(Offset globalPos) => _hitIn(_rowKeys, globalPos);

  String? _hitFavorite(Offset globalPos) => _hitIn(_favoriteKeys, globalPos);

  String? _hitIn(Map<String, GlobalKey> keys, Offset globalPos) {
    // 倒序遍历：后构建的行（更深层子级）优先命中
    for (final entry in keys.entries.toList().reversed) {
      final rect = _rectOf(entry.value);
      if (rect != null && rect.contains(globalPos)) return entry.key;
    }
    return null;
  }

  /// 更新悬停高亮 + 经过即展开
  void _updateHover(Offset globalPos) {
    if (!_visible || _pinned) return;

    final inCancel = _cancelZoneRect.contains(globalPos);
    final favoriteId = inCancel ? null : _hitFavorite(globalPos);
    final tagId =
        (inCancel || favoriteId != null) ? null : _hitRow(globalPos);

    if (tagId != _hoveredTagId || favoriteId != _hoveredFavoriteId) {
      setState(() {
        _hoveredTagId = tagId;
        _hoveredFavoriteId = favoriteId;
      });
    }

    // 经过有子级的标签立即展开（子级插入在该行下方，不会改变当前行命中位置）
    if (tagId != null &&
        !_expandedIds.contains(tagId) &&
        _childrenOf(tagId).isNotEmpty) {
      setState(() => _expandedIds.add(tagId));
    }
  }

  // 边缘自动滚动

  void _updateAutoScroll(Offset globalPos) {
    final panel = _panelRect;
    if (panel == null || !panel.contains(globalPos)) {
      _stopAutoScroll();
      return;
    }

    final favoriteRect = _rectOf(_favoriteColumnKey);
    _scrollTarget = (favoriteRect != null && globalPos.dx >= favoriteRect.left)
        ? _favoriteScroll
        : _treeScroll;

    double speed = 0;
    if (globalPos.dy < panel.top + _edge) {
      final ratio =
          (1 - (globalPos.dy - panel.top) / _edge).clamp(0.0, 1.0).toDouble();
      speed = -ratio * 14; // 向上
    } else if (globalPos.dy > panel.bottom - _edge) {
      final ratio =
          (1 - (panel.bottom - globalPos.dy) / _edge).clamp(0.0, 1.0).toDouble();
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
    final controller = _scrollTarget;
    if (!mounted || !_visible || controller == null || !controller.hasClients) {
      _stopAutoScroll();
      return;
    }
    final position = controller.position;
    final next = (controller.offset + _scrollSpeed)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((next - controller.offset).abs() < 0.01) {
      _stopAutoScroll();
      return;
    }
    controller.jumpTo(next);
    // 行随滚动移动，重新命中
    _updateHover(_dragPos);
  }

  void _stopAutoScroll() {
    _scrollTimer?.cancel();
    _scrollTimer = null;
    _scrollSpeed = 0;
  }

  // 渲染

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    final allTags = ref.watch(tagTreeProvider).valueOrNull ?? const <Tag>[];
    final appliedIds = (ref.watch(currentMediaTagsProvider).valueOrNull ??
            const <Tag>[])
        .map((t) => t.id)
        .toSet();
    final favorites = ref.watch(favoriteTagsProvider);

    final childrenMap = <String, List<Tag>>{};
    for (final t in allTags) {
      if (t.parentId != null) {
        childrenMap.putIfAbsent(t.parentId!, () => []).add(t);
      }
    }
    for (final list in childrenMap.values) {
      list.sort(_byName);
    }
    final roots = allTags.where((t) => t.parentId == null).toList()
      ..sort(_byName);

    return RotatedBox(
      quarterTurns: widget.quarterTurns % 4,
      // 面板/取消区尺寸必须按"换轴后这一帧"的尺寸算：直接用 MediaQuery 会拿到
      // 未换轴的屏幕尺寸，旋转时面板高度会超出视口。
      child: LayoutBuilder(
        builder: (context, constraints) => _buildStack(
          constraints,
          allTags: allTags,
          appliedIds: appliedIds,
          favorites: favorites,
          childrenMap: childrenMap,
          roots: roots,
        ),
      ),
    );
  }

  Widget _buildStack(
    BoxConstraints constraints, {
    required List<Tag> allTags,
    required Set<String> appliedIds,
    required List<Tag> favorites,
    required Map<String, List<Tag>> childrenMap,
    required List<Tag> roots,
  }) {
    final bounded =
        constraints.hasBoundedWidth && constraints.hasBoundedHeight;
    final size = bounded ? constraints.biggest : MediaQuery.sizeOf(context);
    // 手势回调发生在布局之后，缓存本帧尺寸让它们无需再问根节点
    _frameSizeOverride = size;
    final topPad = _frameTopInset;
    // 面板不高于这一帧，避免极窄可用空间下面板溢出
    final maxPanelHeight = (size.height - 24).clamp(120.0, 460.0);
    final panelHeight =
        (size.height * 0.58).clamp(120.0, maxPanelHeight).toDouble();
    final maxFavoriteWidth = (size.width * 0.6).clamp(60.0, 176.0);
    final favoriteWidth =
        (size.width * 0.32).clamp(60.0, maxFavoriteWidth).toDouble();
    // 旋转后面板贴住"媒体底边"；此时物理底栏落在该帧的右侧，改为右侧避让
    final panelBottom = _isRotated ? 8.0 : widget.bottomInset;
    final panelRight = _isRotated ? widget.bottomInset : 0.0;
    final cancelCenter = _cancelCenter(size);

    return Stack(
      key: _rootKey,
      children: [
        // 遮罩：拖动期间吸收误触；固定模式下点击空白关闭
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _pinned ? close : () {},
            child: Container(color: _pinned ? Colors.black54 : Colors.black38),
          ),
        ),

        // 右上角取消区（仅拖拽模式）
        if (!_pinned)
          Positioned(
            top: cancelCenter.dy - 36,
            right: size.width - cancelCenter.dx - 36,
            child: ValueListenableBuilder<Offset>(
              valueListenable: _dragPosNotifier,
              builder: (context, pos, _) {
                final inCancel = (pos - cancelCenter).distance <= 48;
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

        // 浮层面板
        Positioned(
          left: 0,
          right: panelRight,
          bottom: panelBottom,
          height: panelHeight,
          child: Container(
            key: _panelKey,
            decoration: BoxDecoration(
              color: const Color(0xF21E1E24),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
              ),
            ),
            child: Column(
              children: [
                _buildHeader(appliedIds.length, allTags),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 左：标签树
                      Expanded(
                        child: allTags.isEmpty
                            ? const Center(
                                child: Text('暂无标签',
                                    style: TextStyle(color: Colors.white38)),
                              )
                            : ListView(
                                controller: _treeScroll,
                                padding: const EdgeInsets.only(bottom: 12),
                                children: [
                                  for (final root in roots)
                                    _buildTreeRow(
                                      root,
                                      childrenMap,
                                      0,
                                      appliedIds,
                                    ),
                                ],
                              ),
                      ),
                      Container(width: 1, color: Colors.white12),
                      // 右：快捷标签
                      SizedBox(
                        key: _favoriteColumnKey,
                        width: favoriteWidth,
                        child: _buildFavoriteColumn(favorites, appliedIds),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // 拖拽跟随提示（仅拖拽模式，且只随手指位置刷新）
        if (!_pinned)
          ValueListenableBuilder<Offset>(
            valueListenable: _dragPosNotifier,
            builder: (context, pos, _) => _buildDragIndicator(pos, size, topPad),
          ),
      ],
    );
  }

  /// 面板头部
  Widget _buildHeader(int appliedCount, List<Tag> allTags) {
    final expandableIds = {
      for (final t in allTags)
        if (t.parentId != null) t.parentId!,
    };
    final allExpanded =
        expandableIds.isNotEmpty && _expandedIds.containsAll(expandableIds);

    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 12, right: 8, bottom: 4),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 3,
            decoration: BoxDecoration(
              color: Colors.white30,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 6),
          if (_pinned)
            Row(
              children: [
                const Text('快速打标签',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
                const SizedBox(width: 8),
                Text('已选 $appliedCount',
                    style: const TextStyle(color: Colors.white54, fontSize: 11)),
                const Spacer(),
                if (expandableIds.isNotEmpty)
                  _HeaderButton(
                    icon: allExpanded ? Icons.unfold_less : Icons.unfold_more,
                    tooltip: allExpanded ? '全部收起' : '全部展开',
                    onTap: () => setState(() {
                      if (allExpanded) {
                        _expandedIds.clear();
                      } else {
                        _expandedIds.addAll(expandableIds);
                      }
                    }),
                  ),
                _HeaderButton(
                  icon: Icons.close,
                  tooltip: '关闭',
                  onTap: close,
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: Text(
                    '松手到标签上 = 添加/移除 · 经过父标签即展开 · 右上角 = 取消\n'
                    '长按底部「标签」按钮可固定此面板并管理快捷标签',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                  ),
                ),
                Text('已选 $appliedCount',
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildFavoriteColumn(List<Tag> favorites, Set<String> appliedIds) {
    if (favorites.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(
          child: Text(
            '暂无快捷标签\n在标签行或「选择标签」页点 ★ 收藏',
            style: TextStyle(color: Colors.white38, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _favoriteScroll,
      padding: const EdgeInsets.fromLTRB(6, 2, 6, 12),
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        final tag = favorites[index];
        final key = _favoriteKeys[tag.id] ??= GlobalKey();
        return _FavoriteRow(
          key: key,
          tag: tag,
          applied: appliedIds.contains(tag.id),
          hovered: _hoveredFavoriteId == tag.id,
          interactive: _pinned,
          onTap: _pinned ? () => _toggleTag(tag.id) : null,
          onLongPress: _pinned ? () => _showFavoriteMenu(tag) : null,
        );
      },
    );
  }

  /// 快捷标签管理菜单（收藏状态持久化在服务端）
  Future<void> _showFavoriteMenu(Tag tag) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              dense: true,
              title: Text(tag.fullPath ?? tag.name,
                  style: const TextStyle(fontSize: 13)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.star_border, size: 20),
              title: const Text('移出快捷标签'),
              onTap: () {
                Navigator.pop(sheetContext);
                _setFavorite(tag, false);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 拖拽跟随提示
  Widget _buildDragIndicator(Offset pos, Size size, double topPad) {
    final inCancel = _cancelZoneRect.contains(pos);
    final hoveredTag = _hoveredTagId == null ? null : _findTag(_hoveredTagId!);
    final hoveredFavorite =
        _hoveredFavoriteId == null ? null : _findTag(_hoveredFavoriteId!);
    final target = hoveredFavorite ?? hoveredTag;
    final applied =
        target != null && _appliedTagIds.contains(target.id);

    final String label;
    if (inCancel) {
      label = '取消';
    } else if (target != null) {
      label = applied ? '移除「${target.name}」' : '添加「${target.name}」';
    } else {
      label = '拖动到标签上';
    }

    return Positioned(
      left: (pos.dx + 14).clamp(0.0, size.width - 170).toDouble(),
      top: (pos.dy - 26).clamp(topPad, size.height - 100).toDouble(),
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white38),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                inCancel
                    ? Icons.close
                    : applied
                        ? Icons.remove_circle_outline
                        : Icons.add_circle_outline,
                size: 16,
                color: inCancel
                    ? Colors.redAccent
                    : applied
                        ? Colors.orange
                        : Colors.amber,
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Tag? _findTag(String id) {
    for (final t in _allTags) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// 递归构建标签树行（只展开 [_expandedIds] 中的子级）
  Widget _buildTreeRow(
    Tag tag,
    Map<String, List<Tag>> childrenMap,
    int depth,
    Set<String> appliedIds,
  ) {
    final key = _rowKeys[tag.id] ??= GlobalKey();
    final children = childrenMap[tag.id] ?? const <Tag>[];
    final expanded = _expandedIds.contains(tag.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TagRow(
          key: key,
          tag: tag,
          depth: depth,
          hasChildren: children.isNotEmpty,
          expanded: expanded,
          applied: appliedIds.contains(tag.id),
          hovered: _hoveredTagId == tag.id,
          interactive: _pinned,
          onTap: _pinned ? () => _toggleTag(tag.id) : null,
          onToggleExpand:
              _pinned ? () => setState(() => _toggleExpanded(tag.id)) : null,
        ),
        if (expanded && children.isNotEmpty)
          for (final child in children)
            _buildTreeRow(child, childrenMap, depth + 1, appliedIds),
      ],
    );
  }

  void _toggleExpanded(String tagId) {
    if (!_expandedIds.remove(tagId)) _expandedIds.add(tagId);
  }

  static int _byName(Tag a, Tag b) =>
      (a.fullPath ?? a.name).compareTo(b.fullPath ?? b.name);
}

/// 面板头部图标按钮
class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: Colors.white70),
        ),
      ),
    );
  }
}

/// 标签树行
class _TagRow extends StatelessWidget {
  final Tag tag;
  final int depth;
  final bool hasChildren;
  final bool expanded;
  final bool applied;
  final bool hovered;

  /// 固定模式下可点击交互
  final bool interactive;
  final VoidCallback? onTap;
  final VoidCallback? onToggleExpand;

  const _TagRow({
    super.key,
    required this.tag,
    required this.depth,
    required this.hasChildren,
    required this.expanded,
    required this.applied,
    required this.hovered,
    required this.interactive,
    this.onTap,
    this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context) {
    final background = hovered
        ? (applied
            ? Colors.orange.withValues(alpha: 0.40)
            : Colors.blue.withValues(alpha: 0.40))
        : (applied ? Colors.blue.withValues(alpha: 0.15) : Colors.white10);

    final row = Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      padding: EdgeInsets.only(
        left: 10.0 + depth * 18,
        right: 6,
        top: 7,
        bottom: 7,
      ),
      decoration: BoxDecoration(
        color: background,
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
            size: 17,
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
            interactive && onToggleExpand != null
                ? InkWell(
                    onTap: onToggleExpand,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        expanded ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                        color: Colors.white54,
                      ),
                    ),
                  )
                : Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: Colors.white38,
                  ),
        ],
      ),
    );

    return interactive && onTap != null
        ? InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: row,
          )
        : row;
  }
}

/// 快捷标签行
class _FavoriteRow extends StatelessWidget {
  final Tag tag;
  final bool applied;
  final bool hovered;
  final bool interactive;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _FavoriteRow({
    super.key,
    required this.tag,
    required this.applied,
    required this.hovered,
    required this.interactive,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final row = Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: hovered
            ? (applied
                ? Colors.orange.withValues(alpha: 0.40)
                : Colors.blue.withValues(alpha: 0.40))
            : (applied ? Colors.blue.withValues(alpha: 0.15) : Colors.white10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hovered ? Colors.white : Colors.white12,
          width: hovered ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            applied ? Icons.check_circle : Icons.star,
            size: 15,
            color: applied ? Colors.amber : Colors.amber.shade200,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              tag.name,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    return interactive
        ? InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(8),
            child: row,
          )
        : row;
  }
}
