import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/providers/gallery_providers.dart';

/// 快速滚动条轨道宽度
const double _kScrollbarTrackWidth = 8;
/// 快速滚动条在 GridView 右侧的总占宽（轨道 + 边距）
const double _kScrollbarReservedWidth = _kScrollbarTrackWidth + 4;

/// 媒体文件网格视图组件
/// - 呈现图片/视频的缩略图 (对应 thumb_path)
/// - 初始一行四个, 可上下滚动
/// - 放大/缩小手势改变每行数量: 3, 4, 8, 16
/// - 长按进入选择模式, 可多选并进行捆绑分组或删除操作
class MediasBrowserPage extends ConsumerStatefulWidget {
  const MediasBrowserPage({super.key});

  @override
  ConsumerState<MediasBrowserPage> createState() => _MediasBrowserPageState();
}

class _MediasBrowserPageState extends ConsumerState<MediasBrowserPage> {
  /// 是否处于选择模式
  bool _isSelectionMode = false;
  
  /// 选中的媒体 ID 集合
  final Set<String> _selectedIds = {};
  
  /// 选中顺序列表 (用于捆绑时确定主文件)
  final List<String> _selectionOrder = [];

  /// 滚动控制器
  final ScrollController _scrollController = ScrollController();
  
  /// 当前检阅项的 GlobalKey，用于 Scrollable.ensureVisible 精确定位
  final GlobalKey _currentItemKey = GlobalKey(debugLabel: 'currentMediaItem');
  
  /// 瀑布流模式各列的独立 ScrollController（实现按列虚拟化）
  final List<ScrollController> _waterfallColumnControllers = [];
  
  /// 瀑布流滚动同步锁，防止联动时递归触发
  bool _syncingWaterfall = false;

  /// 是否已执行初始滚动
  bool _hasScrolledToInitial = false;

  /// 是否正在拖拽快速滚动条
  final bool _isDraggingScrollbar = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onMasterScrollForWaterfall);
    _teardownWaterfallColumns();
    _scrollController.dispose();
    super.dispose();
  }

  /// 滚动到当前媒体文件所在行（使其位于视图第一行）
  ///
  /// 优先使用 [Scrollable.ensureVisible] 通过 [GlobalKey] 精确定位；
  /// 若目标项尚未被懒加载构建（offscreen），回退到估算偏移量，
  /// 待滚动到附近、目标构建完成后再做二次精确定位。
  void _scrollToCurrentIndex({bool animate = true}) {
    final currentMedia = ref.read(currentMediaAssetProvider);
    if (currentMedia == null) return;
    final allAssets = ref.read(mediaAssetListProvider).valueOrNull ?? [];
    final indexInAll = allAssets.indexWhere((a) => a.id == currentMedia.id);
    if (indexInAll < 0) return;

    _doScrollToCurrent(animate: animate, fallbackIndex: indexInAll);
  }

  void _doScrollToCurrent({required bool animate, required int fallbackIndex}) {
    // 首选: GlobalKey 精确定位
    final ctx = _currentItemKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.0,
        duration: animate ? const Duration(milliseconds: 300) : Duration.zero,
        curve: Curves.easeOut,
      );
      // 瀑布流模式: ensureVisible 只滚动了当前列，需同步到其他列及主控制器
      if (_waterfallColumnControllers.isNotEmpty) {
        Future.delayed(animate ? const Duration(milliseconds: 350) : Duration.zero, () {
          if (mounted) {
            _syncWaterfallAfterEnsureVisible();
          }
        });
      }
      return;
    }

    // 回退: 基于估算偏移量（目标项未在可视范围内构建时）
    final columns = ref.read(galleryGridColumnsProvider);
    final cellW = _cellWidth(columns);
    final row = fallbackIndex ~/ columns;
    final targetOffset = row * (cellW + 2);

    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          targetOffset.clamp(0.0, maxScroll),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(targetOffset.clamp(0.0, maxScroll));
      }
    }

    // 滚动到附近后, 等待目标项构建完成, 再进行精确定位
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx2 = _currentItemKey.currentContext;
      if (ctx2 != null && mounted) {
        Scrollable.ensureVisible(
          ctx2,
          alignment: 0.0,
          duration: animate ? const Duration(milliseconds: 200) : Duration.zero,
          curve: Curves.easeOut,
        );
      }
    });
  }
  
  /// 在内容首次渲染后执行初始滚动 — 等待两帧确保完整布局
  void _performInitialScrollIfNeeded() {
    if (_hasScrolledToInitial) return;
    _hasScrolledToInitial = true;
    
    // 两帧延迟: 第一帧完成 build+layout, 第二帧确保图片加载后的二次布局也完成
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scrollToCurrentIndex(animate: false);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // 使用包含已删除文件的列表
    final assetsAsync = ref.watch(mediaAssetListProvider);
    final columns = ref.watch(galleryGridColumnsProvider);
    // 获取当前媒体的 ID，而不是索引
    final currentMedia = ref.watch(currentMediaAssetProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(_isSelectionMode 
            ? '已选择 ${_selectedIds.length} 项' 
            : _buildTitle(columns)),
        actions: [
          // 预览模式切换
          PopupMenuButton<GalleryGridPreviewMode>(
            icon: const Icon(Icons.grid_view, size: 20),
            tooltip: '预览模式',
            color: Colors.grey[900],
            onSelected: (mode) {
              ref.read(galleryGridPreviewModeNotifierProvider.notifier).setMode(mode);
              _hasScrolledToInitial = false;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToCurrentIndex();
                });
              });
            },
            itemBuilder: (context) {
              final current = ref.watch(galleryGridPreviewModeNotifierProvider);
              return GalleryGridPreviewMode.values.map((mode) {
                return PopupMenuItem(
                  value: mode,
                  child: Row(
                    children: [
                      Icon(
                        mode == current ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(_modeLabel(mode)),
                    ],
                  ),
                );
              }).toList();
            },
          ),
          // 缩小 (增加列数)
          IconButton(
            icon: const Icon(Icons.zoom_out),
            tooltip: '缩小',
            onPressed: () {
              ref.read(galleryGridColumnsProvider.notifier).zoomOut();
              // 等待两帧确保布局完成后再滚动
              WidgetsBinding.instance.addPostFrameCallback((_) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToCurrentIndex();
                });
              });
            },
          ),
          // 放大 (减少列数)
          IconButton(
            icon: const Icon(Icons.zoom_in),
            tooltip: '放大',
            onPressed: () {
              ref.read(galleryGridColumnsProvider.notifier).zoomIn();
              // 等待两帧确保布局完成后再滚动
              WidgetsBinding.instance.addPostFrameCallback((_) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToCurrentIndex();
                });
              });
            },
          ),
          if (_isSelectionMode) ...[
            // 全选/取消全选
            IconButton(
              icon: const Icon(Icons.select_all),
              tooltip: '全选',
              onPressed: () => _selectAll(assetsAsync.valueOrNull ?? []),
            ),
            // 取消选择模式
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: '取消',
              onPressed: _exitSelectionMode,
            ),
          ],
        ],
      ),
      body: assetsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        error: (error, stack) => Center(
          child: Text(
            '加载失败: $error',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        data: (assets) {
          if (assets.isEmpty) {
            return const Center(
              child: Text(
                '暂无媒体文件',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          // 数据加载完成后执行初始滚动
          _performInitialScrollIfNeeded();

          final mode = ref.watch(galleryGridPreviewModeNotifierProvider);
          
          // 根据预览模式构建不同的布局
          Widget gridChild;
          switch (mode) {
            case GalleryGridPreviewMode.thumb:
              gridChild = _buildThumbGrid(assets, columns, currentMedia);
            case GalleryGridPreviewMode.preview:
              gridChild = _buildProportionalGrid(assets, columns, currentMedia);
            case GalleryGridPreviewMode.waterfall:
              gridChild = _buildWaterfallGrid(assets, columns, currentMedia);
          }

          return _DraggableScrollWrapper(
            scrollController: _scrollController,
            itemCount: assets.length,
            crossAxisCount: columns,
            child: gridChild,
          );
        },
      ),
      bottomNavigationBar: _isSelectionMode && _selectedIds.isNotEmpty
          ? _buildBottomBar()
          : null,
    );
  }

  /// 构建底部操作栏
  Widget _buildBottomBar() {
    // 检查选中项中是否有已删除的
    final allAssets = ref.read(mediaAssetListProvider).valueOrNull ?? [];
    final hasDeletedSelected = _selectedIds.any((id) {
      final asset = allAssets.firstWhere((a) => a.id == id, orElse: () => allAssets.first);
      return asset.isDeleted;
    });
    final hasNonDeletedSelected = _selectedIds.any((id) {
      final asset = allAssets.firstWhere((a) => a.id == id, orElse: () => allAssets.first);
      return !asset.isDeleted;
    });
    
    return Container(
      color: Colors.grey[900],
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 捆绑按钮 (需要至少选择2个)
            if (_selectedIds.length >= 2)
              _BottomButton(
                icon: Icons.link,
                label: '捆绑',
                onPressed: _bundleSelected,
              ),
            // 恢复按钮 (有已删除的选中项时显示)
            if (hasDeletedSelected)
              _BottomButton(
                icon: Icons.restore,
                label: '恢复',
                color: Colors.green,
                onPressed: _restoreSelected,
              ),
            // 删除按钮 (有未删除的选中项时显示)
            if (hasNonDeletedSelected)
              _BottomButton(
                icon: Icons.delete,
                label: '删除',
                color: Colors.red,
                onPressed: _deleteSelected,
              ),
          ],
        ),
      ),
    );
  }

  /// 处理点击
  void _handleTap(MediaAsset asset, int index) {
    if (_isSelectionMode) {
      _toggleSelection(asset.id);
    } else {
      // 如果文件已删除，双击取消删除 (通过 onDoubleTap 回调处理)
      if (asset.isDeleted) {
        return; // 不跳转，由 _GridTile 的双击处理恢复
      }
      
      // 直接使用 index 跳转（现在 mediaAssetListProvider 包含所有文件）
      ref.read(galleryCurrentIndexProvider.notifier).update(index);
      Navigator.pop(context);
    }
  }

  /// 处理长按
  void _handleLongPress(MediaAsset asset) {
    if (!_isSelectionMode) {
      setState(() {
        _isSelectionMode = true;
        _selectedIds.add(asset.id);
        _selectionOrder.add(asset.id);
      });
    }
  }

  /// 切换选中状态
  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        _selectionOrder.remove(id);
      } else {
        _selectedIds.add(id);
        _selectionOrder.add(id);
      }
      
      // 如果没有选中项，退出选择模式
      if (_selectedIds.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  /// 全选
  void _selectAll(List<MediaAsset> assets) {
    setState(() {
      if (_selectedIds.length == assets.length) {
        // 已全选，则取消全选
        _selectedIds.clear();
        _selectionOrder.clear();
        _isSelectionMode = false;
      } else {
        // 全选
        _selectedIds.clear();
        _selectionOrder.clear();
        for (final asset in assets) {
          _selectedIds.add(asset.id);
          _selectionOrder.add(asset.id);
        }
      }
    });
  }

  /// 退出选择模式
  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
      _selectionOrder.clear();
    });
  }

  /// 捆绑选中的媒体文件
  Future<void> _bundleSelected() async {
    if (_selectionOrder.length < 2) return;

    final leadId = _selectionOrder.first;
    final memberIds = _selectionOrder.skip(1).toList();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('捆绑媒体文件'),
        content: Text(
          '将 ${memberIds.length} 个文件捆绑到第一个选中的文件？\n'
          '捆绑后，被捆绑的文件将不会单独显示。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // 保存当前滚动位置
      final scrollOffset = _scrollController.offset;
      
      await ref.read(mediaAssetListProvider.notifier).bundleMedia(leadId, memberIds);
      
      // 退出选择模式但保持滚动位置
      setState(() {
        _isSelectionMode = false;
        _selectedIds.clear();
        _selectionOrder.clear();
      });
      
      // 恢复滚动位置
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(
            scrollOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
          );
        }
      });
    }
  }

  /// 删除选中的媒体文件
  Future<void> _deleteSelected() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除媒体文件'),
        content: Text('确定要删除选中的 ${_selectedIds.length} 个文件吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // 保存当前滚动位置
      final scrollOffset = _scrollController.offset;
      
      for (final id in _selectedIds) {
        await ref.read(mediaAssetListProvider.notifier).markDeleted(id, deleted: true);
      }
      
      // 退出选择模式但保持滚动位置
      setState(() {
        _isSelectionMode = false;
        _selectedIds.clear();
        _selectionOrder.clear();
      });
      
      // 恢复滚动位置
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(
            scrollOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
          );
        }
      });
    }
  }

  /// 恢复选中的已删除媒体文件
  Future<void> _restoreSelected() async {
    // 保存当前滚动位置
    final scrollOffset = _scrollController.offset;
    
    for (final id in _selectedIds) {
      await ref.read(mediaAssetListProvider.notifier).markDeleted(id, deleted: false);
    }
    
    // 退出选择模式但保持滚动位置
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
      _selectionOrder.clear();
    });
    
    // 恢复滚动位置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(
          scrollOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        );
      }
    });
  }

  /// 构建标题
  String _buildTitle(int columns) {
    final mode = ref.read(galleryGridPreviewModeNotifierProvider);
    return '${_modeLabel(mode)} ($columns列)';
  }

  /// 预览模式标签
  String _modeLabel(GalleryGridPreviewMode mode) {
    switch (mode) {
      case GalleryGridPreviewMode.thumb:
        return '缩略预览';
      case GalleryGridPreviewMode.preview:
        return '等比预览';
      case GalleryGridPreviewMode.waterfall:
        return '瀑布预览';
    }
  }

  /// 计算单个 cell 的宽度
  double _cellWidth(int columns) {
    final screenWidth = MediaQuery.of(context).size.width;
    return (screenWidth - _kScrollbarReservedWidth - 4 - (columns - 1) * 2) / columns;
  }

  /// 模式一: 缩略图网格 (原有逻辑)
  Widget _buildThumbGrid(List<MediaAsset> assets, int columns, MediaAsset? currentMedia) {
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(2),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: assets.length,
      itemBuilder: (context, index) => _buildGridTile(assets, index, currentMedia),
    );
  }

  /// 模式二: 等比预览网格
  Widget _buildProportionalGrid(List<MediaAsset> assets, int columns, MediaAsset? currentMedia) {
    final spacing = 2.0;
    final cellW = _cellWidth(columns);
    final rows = (assets.length / columns).ceil();

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(2),
      itemCount: rows,
      itemBuilder: (ctx, rowIndex) {
        final start = rowIndex * columns;
        final end = min(start + columns, assets.length);

        return Padding(
          padding: EdgeInsets.only(bottom: spacing),
          child: IntrinsicHeight(
            child: Row(
              // 行间元素居中
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (int i = start; i < end; i++) ...[
                  if (i > start) const SizedBox(width: 2),
                  SizedBox(
                    width: cellW,
                    child: _ProportionalCell(
                      key: currentMedia?.id == assets[i].id
                          ? _currentItemKey
                          : ValueKey('prop_${assets[i].id}'),
                      asset: assets[i],
                      isSelected: _selectedIds.contains(assets[i].id),
                      isCurrent: currentMedia?.id == assets[i].id,
                      selectionIndex: () {
                        final idx = _selectionOrder.indexOf(assets[i].id);
                        return idx >= 0 ? idx + 1 : null;
                      }(),
                      isSelectionMode: _isSelectionMode,
                      onTap: () => _handleTap(assets[i], i),
                      onLongPress: () => _handleLongPress(assets[i]),
                      onDoubleTap: assets[i].isDeleted ? () => _undoDeleteSingle(assets[i]) : null,
                    ),
                  ),
                ],
                // 末行补齐占位
                for (int i = end; i < start + columns; i++) ...[
                  if (i > start || end > start) const SizedBox(width: 2),
                  SizedBox(width: cellW),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// 模式三: 瀑布流布局 — 列式虚拟化
  /// 
  /// 每列使用独立的 [ListView.builder]，通过 [LayoutBuilder] 获取可用高度并
  /// 用 [SizedBox] 显式约束列高。仅构建可视区域内的项，大幅降低初始构建耗时。
  /// 列间滚动通过 [NotificationListener] 联动，右侧拖拽条通过主 [_scrollController] 同步。
  Widget _buildWaterfallGrid(List<MediaAsset> assets, int columns, MediaAsset? currentMedia) {
    final cellW = _cellWidth(columns);

    // 将媒体文件分配到各列 (轮询)
    final List<List<MediaAsset>> columnAssets = List.generate(columns, (_) => []);
    final List<List<int>> columnIndices = List.generate(columns, (_) => []);
    for (int i = 0; i < assets.length; i++) {
      final col = i % columns;
      columnAssets[col].add(assets[i]);
      columnIndices[col].add(i);
    }

    // 确保列控制器就绪
    _setupWaterfallColumns(columns);

    // LayoutBuilder 获取 _DraggableScrollWrapper 分配的可用高度，
    // 显式约束每列 ListView 的高度是虚拟化生效的关键。
    return NotificationListener<ScrollNotification>(
      onNotification: _onWaterfallScrollNotification,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final outerPad = 4.0; // EdgeInsets.all(2) → 上下各 2
          final columnH = (constraints.maxHeight - outerPad).clamp(0.0, double.infinity);

          return Padding(
            padding: const EdgeInsets.all(2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int col = 0; col < columns; col++) ...[
                  if (col > 0) const SizedBox(width: 2),
                  SizedBox(
                    width: cellW,
                    height: columnH,
                    child: ListView.builder(
                      controller: col == 0
                          ? _scrollController
                          : _waterfallColumnControllers[col - 1],
                      padding: EdgeInsets.zero,
                      itemCount: columnAssets[col].length,
                      itemBuilder: (ctx, i) => Padding(
                        padding: EdgeInsets.only(
                          bottom: i < columnAssets[col].length - 1 ? 2 : 0,
                        ),
                        child: _WaterfallCell(
                          key: currentMedia?.id == columnAssets[col][i].id
                              ? _currentItemKey
                              : ValueKey('wf_${columnAssets[col][i].id}'),
                          asset: columnAssets[col][i],
                          cellWidth: cellW,
                          isSelected: _selectedIds.contains(columnAssets[col][i].id),
                          isCurrent: currentMedia?.id == columnAssets[col][i].id,
                          selectionIndex: () {
                            final idx = _selectionOrder.indexOf(columnAssets[col][i].id);
                            return idx >= 0 ? idx + 1 : null;
                          }(),
                          isSelectionMode: _isSelectionMode,
                          onTap: () => _handleTap(columnAssets[col][i], columnIndices[col][i]),
                          onLongPress: () => _handleLongPress(columnAssets[col][i]),
                          onDoubleTap: columnAssets[col][i].isDeleted ? () => _undoDeleteSingle(columnAssets[col][i]) : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  /// 构建网格项 (复用于模式一)
  Widget _buildGridTile(List<MediaAsset> assets, int index, MediaAsset? currentMedia) {
    final asset = assets[index];
    final isSelected = _selectedIds.contains(asset.id);
    final isCurrent = currentMedia?.id == asset.id;
    final selectionIndex = _selectionOrder.indexOf(asset.id);

    return _GridTile(
      key: isCurrent ? _currentItemKey : ValueKey(asset.id),
      asset: asset,
      isSelected: isSelected,
      isCurrent: isCurrent,
      selectionIndex: selectionIndex >= 0 ? selectionIndex + 1 : null,
      isSelectionMode: _isSelectionMode,
      onTap: () => _handleTap(asset, index),
      onLongPress: () => _handleLongPress(asset),
    );
  }

  /// 单个媒体文件的恢复操作 (供模式二/三的双击回调使用)
  Future<void> _undoDeleteSingle(MediaAsset asset) async {
    await ref.read(mediaAssetListProvider.notifier).markDeleted(asset.id, deleted: false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已恢复: ${asset.filePath.split('/').last}'), duration: const Duration(milliseconds: 400)),
      );
    }
  }

  // ──────── 瀑布流列式虚拟化 · 滚动联动 ────────

  /// 初始化瀑布流各列 [ScrollController]
  ///
  /// 第 0 列直接使用主 [_scrollController]（驱动拖拽条 / 滚动定位），
  /// 其余列创建独立的 [ScrollController] 存入 [_waterfallColumnControllers]。
  void _setupWaterfallColumns(int count) {
    _teardownWaterfallColumns();
    // col 0 uses _scrollController; cols 1..n get dedicated controllers
    for (int i = 1; i < count; i++) {
      _waterfallColumnControllers.add(ScrollController());
    }
    // 监听主控制器（col 0）以同步到其他列
    _scrollController.removeListener(_onMasterScrollForWaterfall);
    _scrollController.addListener(_onMasterScrollForWaterfall);
  }

  /// 清理瀑布流子列控制器（不触碰主 [_scrollController]）
  void _teardownWaterfallColumns() {
    for (final ctrl in _waterfallColumnControllers) {
      ctrl.dispose();
    }
    _waterfallColumnControllers.clear();
  }

  /// 捕获任一列 [ListView] 发出的 [ScrollNotification]，同步至主控制器及其他列
  bool _onWaterfallScrollNotification(ScrollNotification notification) {
    if (_syncingWaterfall) return false;
    if (notification is! ScrollUpdateNotification && 
        notification is! ScrollEndNotification) {
      return false;
    }
    _syncingWaterfall = true;
    final offset = notification.metrics.pixels;
    _syncScrollToMainAndPeers(offset, sourceMetrics: notification.metrics);
    _syncingWaterfall = false;
    return false;
  }

  /// 主 [_scrollController] 滚动时（拖拽条/程序定位），同步到所有瀑布流列
  void _onMasterScrollForWaterfall() {
    if (_syncingWaterfall) return;
    _syncingWaterfall = true;
    final offset = _scrollController.offset;
    for (final ctrl in _waterfallColumnControllers) {
      if (ctrl.hasClients && ctrl.offset != offset) {
        ctrl.jumpTo(offset.clamp(0.0, ctrl.position.maxScrollExtent));
      }
    }
    _syncingWaterfall = false;
  }

  /// 以 [offset] 同步主控制器及所有其他列（排除 [sourceMetrics] 所属列避免回跳）
  void _syncScrollToMainAndPeers(double offset, {ScrollMetrics? sourceMetrics}) {
    // 同步主控制器（驱动拖拽条）
    if (_scrollController.hasClients) {
      final clamped = offset.clamp(0.0, _scrollController.position.maxScrollExtent);
      if ((_scrollController.offset - clamped).abs() > 0.5) {
        _scrollController.jumpTo(clamped);
      }
    }
    // 同步其他列
    for (final ctrl in _waterfallColumnControllers) {
      if (!ctrl.hasClients) continue;
      if (sourceMetrics != null && ctrl.position == sourceMetrics) continue;
      final target = offset.clamp(0.0, ctrl.position.maxScrollExtent);
      if ((ctrl.offset - target).abs() > 0.5) {
        ctrl.jumpTo(target);
      }
    }
  }

  /// [Scrollable.ensureVisible] 定位当前项后，将滚动位置同步到瀑布流所有列
  void _syncWaterfallAfterEnsureVisible() {
    if (_waterfallColumnControllers.isEmpty) return;
    final ctx = _currentItemKey.currentContext;
    if (ctx == null) return;
    final scrollable = Scrollable.of(ctx);
    final offset = scrollable.position.pixels;
    _syncingWaterfall = true;
    _syncScrollToMainAndPeers(offset);
    _syncingWaterfall = false;
  }
}

/// 可拖拽快速滚动包装器
/// 在右侧显示一个可拖拽的滚动指示条，类似手机相册的快速滚动功能
class _DraggableScrollWrapper extends StatefulWidget {
  final Widget child;
  final ScrollController scrollController;
  final int itemCount;
  final int crossAxisCount;

  const _DraggableScrollWrapper({
    required this.child,
    required this.scrollController,
    required this.itemCount,
    required this.crossAxisCount,
  });

  @override
  State<_DraggableScrollWrapper> createState() => _DraggableScrollWrapperState();
}

class _DraggableScrollWrapperState extends State<_DraggableScrollWrapper> {
  bool _isDragging = false;
  double _thumbTop = 0;
  double _thumbHeight = 0;
  double _trackHeight = 0;

  static const double _trackWidth = _kScrollbarTrackWidth;
  static const double _thumbMinHeight = 32;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(_DraggableScrollWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_onScroll);
      widget.scrollController.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!_isDragging && mounted) {
      _updateThumbPosition();
    }
  }

  void _updateThumbPosition() {
    if (!widget.scrollController.hasClients) return;
    final position = widget.scrollController.position;
    if (!position.hasContentDimensions) return;

    final maxScroll = position.maxScrollExtent;
    final viewport = position.viewportDimension;
    final totalContent = maxScroll + viewport;

    if (totalContent <= 0) return;

    final ratio = viewport / totalContent;
    final thumbH = (ratio * _trackHeight).clamp(_thumbMinHeight, _trackHeight);
    final scrollRatio = maxScroll > 0 ? position.pixels / maxScroll : 0.0;
    final maxThumbTop = _trackHeight - thumbH;
    final thumbT = scrollRatio * maxThumbTop;

    setState(() {
      _thumbHeight = thumbH;
      _thumbTop = thumbT;
    });
  }

  void _onDragStart(DragStartDetails details) {
    _isDragging = true;
    _onDragUpdate(DragUpdateDetails(
      globalPosition: details.globalPosition,
      delta: Offset.zero,
    ));
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!widget.scrollController.hasClients) return;
    final position = widget.scrollController.position;
    final maxScroll = position.maxScrollExtent;
    if (maxScroll <= 0) return;

    final maxThumbTop = _trackHeight - _thumbHeight;
    if (maxThumbTop <= 0) return;

    final RenderBox box = context.findRenderObject() as RenderBox;
    final localPos = box.globalToLocal(details.globalPosition);
    final ratio = (localPos.dy / _trackHeight).clamp(0.0, 1.0);
    final targetOffset = ratio * maxScroll;

    widget.scrollController.jumpTo(targetOffset.clamp(0.0, maxScroll));
    _updateThumbPosition();
  }

  void _onDragEnd(DragEndDetails details) {
    _isDragging = false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _trackHeight = constraints.maxHeight;
        // 初始化 thumb 位置
        if (_thumbHeight == 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _updateThumbPosition();
          });
        }

        return Stack(
          children: [
            // 主内容区域（右侧留出空间给滚动条）
            Padding(
              padding: const EdgeInsets.only(right: _trackWidth + 4),
              child: widget.child,
            ),
            // 拖拽滚动条
            Positioned(
              right: 2,
              top: 0,
              bottom: 0,
              child: GestureDetector(
                onVerticalDragStart: _onDragStart,
                onVerticalDragUpdate: _onDragUpdate,
                onVerticalDragEnd: _onDragEnd,
                child: Container(
                  width: _trackWidth,
                  color: Colors.transparent, // 透明点击区域
                  child: Stack(
                    children: [
                      // 轨道背景
                      Positioned(
                        left: 2,
                        right: 2,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                      ),
                      // 拖拽滑块
                      Positioned(
                        left: 0,
                        right: 0,
                        top: _thumbTop,
                        child: Container(
                          height: _thumbHeight,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: _isDragging
                                ? Colors.white.withValues(alpha: 0.7)
                                : Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 缩略图文件缓存 (避免重复的文件系统检查)
final Map<String, File?> _thumbnailCache = {};

/// 网格项 - 使用 StatefulWidget 避免每次重建时重新加载缩略图
class _GridTile extends ConsumerStatefulWidget {
  final MediaAsset asset;
  final bool isSelected;
  final bool isCurrent;
  final int? selectionIndex;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _GridTile({
    super.key,
    required this.asset,
    required this.isSelected,
    required this.isCurrent,
    this.selectionIndex,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  ConsumerState<_GridTile> createState() => _GridTileState();
}

class _GridTileState extends ConsumerState<_GridTile> {
  File? _thumbnailFile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  /// 加载缩略图（带缓存）
  Future<void> _loadThumbnail() async {
    final cacheKey = widget.asset.thumbPath ?? widget.asset.filePath;
    
    // 检查缓存
    if (_thumbnailCache.containsKey(cacheKey)) {
      if (mounted) {
        setState(() {
          _thumbnailFile = _thumbnailCache[cacheKey];
          _isLoading = false;
        });
      }
      return;
    }
    
    // 加载缩略图
    final storage = ref.read(galleryStorageProvider);
    File? file;
    
    if (widget.asset.thumbPath != null) {
      file = await storage.getThumbFile(widget.asset.thumbPath!);
    }
    
    // 缓存结果
    _thumbnailCache[cacheKey] = file;
    
    if (mounted) {
      setState(() {
        _thumbnailFile = file;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.asset.isDeleted ? () => _undoDelete() : null,
        onLongPress: widget.onLongPress,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 缩略图
            if (_isLoading)
              _buildPlaceholder()
            else if (_thumbnailFile != null)
              Image.file(
                _thumbnailFile!,
                fit: BoxFit.cover,
                cacheWidth: 150, // 优化内存：16列时每个缩略图很小
                cacheHeight: 150,
                errorBuilder: (context, error, stack) => _buildPlaceholder(),
              )
            else
              _buildPlaceholder(),

            // 选中边框
            if (widget.isSelected)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 3,
                  ),
                ),
              ),

            // 当前浏览位置指示
            if (widget.isCurrent && !widget.isSelectionMode)
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.visibility,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),

            // 编辑图标（非选择模式下显示）
            if (!widget.isSelectionMode && widget.asset.editParams != null)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.edit, color: Colors.amber, size: 14),
                ),
              ),

            // 选择模式下的勾选框
            if (widget.isSelectionMode)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: widget.isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.black54,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: widget.isSelected
                      ? Center(
                          child: Text(
                            widget.selectionIndex?.toString() ?? '✓',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : null,
                ),
              ),

            // 删除标记
            if (widget.asset.isDeleted)
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.delete,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),

            // 捆绑标记
            if (widget.asset.groupId != null)
              Positioned(
                bottom: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.layers,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),

            // 视频标记
            if (widget.asset.isVideo)
              const Positioned(
                bottom: 4,
                right: 4,
                child: Icon(
                  Icons.play_circle_outline,
                  color: Colors.white,
                  size: 24,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _undoDelete() async {
    await ref.read(mediaAssetListProvider.notifier).markDeleted(widget.asset.id, deleted: false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已恢复: ${widget.asset.filePath.split('/').last}'), duration: const Duration(milliseconds: 400)),
      );
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[800],
      child: Icon(
        widget.asset.isVideo ? Icons.videocam : Icons.image,
        color: Colors.grey[600],
      ),
    );
  }
}

/// 预览图文件缓存 (避免重复的文件系统检查)
final Map<String, File?> _previewCache = {};

/// 内禀高度限制组件 - 将子组件的内禀高度和实际布局高度均限制在 maxAspectRatio * width 以内。
///
/// 用于 IntrinsicHeight 行布局中，防止极高的图片撑开整行。
/// maxAspectRatio 表示 maxHeight / width 的上限，例如 4.0 表示高度不超过宽度的 4 倍。
class _IntrinsicHeightCapped extends SingleChildRenderObjectWidget {
  final double maxAspectRatio;

  const _IntrinsicHeightCapped({
    required this.maxAspectRatio,
    required super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderIntrinsicHeightCapped(maxAspectRatio: maxAspectRatio);
  }

  @override
  void updateRenderObject(BuildContext context, _RenderIntrinsicHeightCapped renderObject) {
    renderObject.maxAspectRatio = maxAspectRatio;
  }
}

class _RenderIntrinsicHeightCapped extends RenderProxyBox {
  double maxAspectRatio;

  _RenderIntrinsicHeightCapped({required this.maxAspectRatio});

  @override
  double computeMinIntrinsicHeight(double width) {
    final childHeight = super.computeMinIntrinsicHeight(width);
    final cap = width * maxAspectRatio;
    return childHeight < cap ? childHeight : cap;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    final childHeight = super.computeMaxIntrinsicHeight(width);
    final cap = width * maxAspectRatio;
    return childHeight < cap ? childHeight : cap;
  }

  @override
  void performLayout() {
    if (child != null) {
      final width = constraints.maxWidth;
      // 计算高度上限：如果 constraints 已经有限制则取更小值
      final cap = width * maxAspectRatio;
      final effectiveMaxH = constraints.maxHeight.isFinite
          ? min(constraints.maxHeight, cap)
          : cap;
      child!.layout(
        constraints.copyWith(
          maxHeight: effectiveMaxH.clamp(constraints.minHeight, double.infinity),
        ),
        parentUsesSize: true,
      );
      size = Size(constraints.maxWidth, child!.size.height);
    } else {
      size = Size(constraints.maxWidth, constraints.minHeight);
    }
  }
}

/// 等比预览单元格 (模式二) - 显示预览图，支持宽高比约束
class _ProportionalCell extends ConsumerStatefulWidget {
  final MediaAsset asset;
  final bool isSelected;
  final bool isCurrent;
  final int? selectionIndex;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onDoubleTap;

  const _ProportionalCell({
    super.key,
    required this.asset,
    required this.isSelected,
    required this.isCurrent,
    this.selectionIndex,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
    this.onDoubleTap,
  });

  @override
  ConsumerState<_ProportionalCell> createState() => _ProportionalCellState();
}

class _ProportionalCellState extends ConsumerState<_ProportionalCell> {
  File? _previewFile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  @override
  void didUpdateWidget(_ProportionalCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id) {
      _loadPreview();
    }
  }

  Future<void> _loadPreview() async {
    final cacheKey = widget.asset.previewPath ?? widget.asset.thumbPath ?? widget.asset.filePath;

    if (_previewCache.containsKey(cacheKey)) {
      if (mounted) {
        setState(() {
          _previewFile = _previewCache[cacheKey];
          _isLoading = false;
        });
      }
      return;
    }

    final storage = ref.read(galleryStorageProvider);
    File? file;

    if (widget.asset.previewPath != null) {
      file = await storage.getPreviewFile(widget.asset.previewPath!);
    }
    if (file == null && widget.asset.thumbPath != null) {
      file = await storage.getThumbFile(widget.asset.thumbPath!);
    }

    _previewCache[cacheKey] = file;

    if (mounted) {
      setState(() {
        _previewFile = file;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        onLongPress: widget.onLongPress,
        child: Stack(
          children: [
            // 预览图 - _IntrinsicHeightCapped 限制高度上限 (max 4×宽度)，BoxFit.cover 居中裁切
            if (_isLoading)
              _buildPlaceholder()
            else if (_previewFile != null)
              _IntrinsicHeightCapped(
                maxAspectRatio: 4.0,
                child: Image.file(
                  _previewFile!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stack) => _buildPlaceholder(),
                ),
              )
            else
              _buildPlaceholder(),

            // 选中边框
            if (widget.isSelected)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 3,
                    ),
                  ),
                ),
              ),

            // 当前浏览位置指示
            if (widget.isCurrent && !widget.isSelectionMode)
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.visibility, color: Colors.white, size: 16),
                ),
              ),

            // 编辑图标
            if (!widget.isSelectionMode && widget.asset.editParams != null)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.edit, color: Colors.amber, size: 14),
                ),
              ),

            // 选择模式下的勾选框
            if (widget.isSelectionMode)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: widget.isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.black54,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: widget.isSelected
                      ? Center(
                          child: Text(
                            widget.selectionIndex?.toString() ?? '✓',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        )
                      : null,
                ),
              ),

            // 删除标记
            if (widget.asset.isDeleted)
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.delete, color: Colors.white, size: 12),
                ),
              ),

            // 捆绑标记
            if (widget.asset.groupId != null)
              Positioned(
                bottom: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.layers, color: Colors.white, size: 12),
                ),
              ),

            // 视频标记
            if (widget.asset.isVideo)
              const Positioned(
                bottom: 4,
                right: 4,
                child: Icon(Icons.play_circle_outline, color: Colors.white, size: 24),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        width: double.infinity,
        color: Colors.grey[800],
        child: Icon(
          widget.asset.isVideo ? Icons.videocam : Icons.image,
          color: Colors.grey[600],
        ),
      ),
    );
  }
}

/// 瀑布流单元格 (模式三) - 显示预览图，保持原始宽高比
class _WaterfallCell extends ConsumerStatefulWidget {
  final MediaAsset asset;
  final double cellWidth;
  final bool isSelected;
  final bool isCurrent;
  final int? selectionIndex;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onDoubleTap;

  const _WaterfallCell({
    super.key,
    required this.asset,
    required this.cellWidth,
    required this.isSelected,
    required this.isCurrent,
    this.selectionIndex,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
    this.onDoubleTap,
  });

  @override
  ConsumerState<_WaterfallCell> createState() => _WaterfallCellState();
}

class _WaterfallCellState extends ConsumerState<_WaterfallCell> {
  File? _previewFile;
  bool _isLoading = true;
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  @override
  void didUpdateWidget(_WaterfallCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id) {
      _loadPreview();
    }
  }

  Future<void> _loadPreview() async {
    final cacheKey = widget.asset.previewPath ?? widget.asset.thumbPath ?? widget.asset.filePath;

    if (_previewCache.containsKey(cacheKey)) {
      if (mounted) {
        setState(() {
          _previewFile = _previewCache[cacheKey];
          _isLoading = false;
        });
      }
      return;
    }

    final storage = ref.read(galleryStorageProvider);
    File? file;

    if (widget.asset.previewPath != null) {
      file = await storage.getPreviewFile(widget.asset.previewPath!);
    }
    if (file == null && widget.asset.thumbPath != null) {
      file = await storage.getThumbFile(widget.asset.thumbPath!);
    }

    _previewCache[cacheKey] = file;

    if (mounted) {
      setState(() {
        _previewFile = file;
        _isLoading = false;
      });
    }
  }

  /// 根据图片实际尺寸和 cell 宽度计算显示高度
  double? _displayHeight() {
    if (_imageSize == null || widget.cellWidth <= 0) return null;
    final aspectRatio = _imageSize!.width / _imageSize!.height;
    if (aspectRatio <= 0) return null;
    final rawHeight = widget.cellWidth / aspectRatio;
    // 上限: 4倍宽度
    return min(rawHeight, widget.cellWidth * 4);
  }

  @override
  Widget build(BuildContext context) {
    final displayH = _displayHeight();

    return RepaintBoundary(
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        onLongPress: widget.onLongPress,
        child: Stack(
          children: [
            // 预览图 - 保持原始宽高比
            if (_isLoading)
              _buildPlaceholder(displayH ?? widget.cellWidth)
            else if (_previewFile != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: _buildImage(displayH),
              )
            else
              _buildPlaceholder(displayH ?? widget.cellWidth),

            // 选中边框
            if (widget.isSelected)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 3,
                    ),
                  ),
                ),
              ),

            // 当前浏览位置指示
            if (widget.isCurrent && !widget.isSelectionMode)
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.visibility, color: Colors.white, size: 16),
                ),
              ),

            // 编辑图标
            if (!widget.isSelectionMode && widget.asset.editParams != null)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.edit, color: Colors.amber, size: 14),
                ),
              ),

            // 选择模式下的勾选框
            if (widget.isSelectionMode)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: widget.isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.black54,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: widget.isSelected
                      ? Center(
                          child: Text(
                            widget.selectionIndex?.toString() ?? '✓',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        )
                      : null,
                ),
              ),

            // 删除标记
            if (widget.asset.isDeleted)
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.delete, color: Colors.white, size: 12),
                ),
              ),

            // 捆绑标记
            if (widget.asset.groupId != null)
              Positioned(
                bottom: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.layers, color: Colors.white, size: 12),
                ),
              ),

            // 视频标记
            if (widget.asset.isVideo)
              const Positioned(
                bottom: 4,
                right: 4,
                child: Icon(Icons.play_circle_outline, color: Colors.white, size: 24),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(double? displayH) {
    final img = Image.file(
      _previewFile!,
      fit: BoxFit.cover,
      width: widget.cellWidth,
      height: displayH,
      errorBuilder: (context, error, stack) => _buildPlaceholder(displayH ?? widget.cellWidth),
    );

    // 捕获图片实际尺寸
    final resolved = img.image.resolve(const ImageConfiguration());
    resolved.addListener(ImageStreamListener((info, _) {
      final sz = Size(info.image.width.toDouble(), info.image.height.toDouble());
      if (_imageSize != sz && sz.width > 0 && sz.height > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _imageSize = sz);
        });
      }
    }));

    return img;
  }

  Widget _buildPlaceholder(double height) {
    return Container(
      width: widget.cellWidth,
      height: height,
      color: Colors.grey[800],
      child: Icon(
        widget.asset.isVideo ? Icons.videocam : Icons.image,
        color: Colors.grey[600],
      ),
    );
  }
}

/// 底部按钮
class _BottomButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onPressed;

  const _BottomButton({
    required this.icon,
    required this.label,
    this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: color ?? Colors.white),
      label: Text(
        label,
        style: TextStyle(color: color ?? Colors.white),
      ),
    );
  }
}