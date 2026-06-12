import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/providers/gallery_providers.dart';

/// 快速滚动条轨道宽度
const double _kScrollbarTrackWidth = 8;
/// 快速滚动条在 GridView 右侧的总占宽（轨道 + 边距）
const double _kScrollbarReservedWidth = _kScrollbarTrackWidth + 4;

/// 预览模式下的宽高比约束范围
const double _kMinAspectRatio = 0.5; // 1:2
const double _kMaxAspectRatio = 2.0; // 2:1

/// 媒体文件网格视图组件
/// - 呈现图片/视频的缩略图或预览图
/// - 支持三种预览模式：方形缩略图 / 预览图网格 / 瀑布流
/// - 放大/缩小手势改变每行数量: 3, 4, 8, 16
/// - 长按进入选择模式, 可多选并进行捆绑分组或删除操作
class MediasGridViewPage extends ConsumerStatefulWidget {
  const MediasGridViewPage({super.key});

  @override
  ConsumerState<MediasGridViewPage> createState() => _MediasGridViewPageState();
}

class _MediasGridViewPageState extends ConsumerState<MediasGridViewPage> {
  /// 是否处于选择模式
  bool _isSelectionMode = false;
  
  /// 选中的媒体 ID 集合
  final Set<String> _selectedIds = {};
  
  /// 选中顺序列表 (用于捆绑时确定主文件)
  final List<String> _selectionOrder = [];

  /// 滚动控制器
  final ScrollController _scrollController = ScrollController();
  
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
    _scrollController.dispose();
    super.dispose();
  }

  /// 滚动到当前媒体文件所在行（使其位于第一行）
  void _scrollToCurrentIndex({bool animate = true}) {
    final currentMedia = ref.read(currentMediaAssetProvider);
    if (currentMedia == null) return;

    final allAssets = ref.read(mediaAssetListProvider).valueOrNull ?? [];
    final indexInAll = allAssets.indexWhere((a) => a.id == currentMedia.id);

    if (indexInAll < 0 || allAssets.isEmpty) return;
    if (!_scrollController.hasClients) return;

    final columns = ref.read(galleryGridColumnsProvider);
    final mode = ref.read(galleryGridPreviewModeNotifierProvider);

    double targetOffset;

    if (mode == GalleryGridPreviewMode.thumb) {
      // 方形缩略图模式：固定行高
      final row = indexInAll ~/ columns;
      final screenWidth = MediaQuery.of(context).size.width;
      final itemSize = (screenWidth - _kScrollbarReservedWidth - 4 - (columns - 1) * 2) / columns;
      targetOffset = row * (itemSize + 2);
    } else {
      // 预览/瀑布模式：累加估算高度
      final screenWidth = MediaQuery.of(context).size.width;
      final itemWidth = (screenWidth - _kScrollbarReservedWidth - 4 - (columns - 1) * 2) / columns;

      if (mode == GalleryGridPreviewMode.preview) {
        // 按行累加
        final row = indexInAll ~/ columns;
        targetOffset = 0;
        for (int r = 0; r < row; r++) {
          final rowStart = r * columns;
          final rowEnd = (rowStart + columns).clamp(0, allAssets.length);
          double maxRowHeight = 0;
          for (int i = rowStart; i < rowEnd; i++) {
            final h = _estimateItemHeight(allAssets[i], itemWidth);
            if (h > maxRowHeight) maxRowHeight = h;
          }
          targetOffset += maxRowHeight + 2;
        }
      } else {
        // 瀑布模式：使用分配列计算
        final itemHeights = allAssets.map((a) => _estimateItemHeight(a, itemWidth)).toList();
        final columnHeights = List<double>.filled(columns, 0);
        final columnAssignments = List<int>.filled(allAssets.length, 0);
        for (int i = 0; i < allAssets.length; i++) {
          int shortestCol = 0;
          for (int c = 1; c < columns; c++) {
            if (columnHeights[c] < columnHeights[shortestCol]) {
              shortestCol = c;
            }
          }
          columnAssignments[i] = shortestCol;
          columnHeights[shortestCol] += itemHeights[i] + 2;
        }
        // 估算当前项在瀑布流中的纵向位置
        final col = columnAssignments[indexInAll];
        double yPos = 0;
        for (int i = 0; i < indexInAll; i++) {
          if (columnAssignments[i] == col) {
            yPos += itemHeights[i] + 2;
          }
        }
        targetOffset = yPos;
      }
    }

    final maxScroll = _scrollController.position.maxScrollExtent;
    final clampedOffset = targetOffset.clamp(0.0, maxScroll);

    if (animate) {
      _scrollController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(clampedOffset);
    }
  }
  
  /// 在 GridView 首次渲染数据后执行初始滚动
  void _performInitialScrollIfNeeded() {
    if (_hasScrolledToInitial) return;
    _hasScrolledToInitial = true;
    
    // 使用短延迟确保 GridView 完成布局和尺寸计算
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        _scrollToCurrentIndex(animate: false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final assetsAsync = ref.watch(mediaAssetListProvider);
    final columns = ref.watch(galleryGridColumnsProvider);
    final currentMedia = ref.watch(currentMediaAssetProvider);
    final previewMode = ref.watch(galleryGridPreviewModeNotifierProvider);

    // 模式名称映射
    String modeLabel;
    IconData modeIcon;
    switch (previewMode) {
      case GalleryGridPreviewMode.preview:
        modeLabel = '预览';
        modeIcon = Icons.grid_view;
        break;
      case GalleryGridPreviewMode.waterfall:
        modeLabel = '瀑布';
        modeIcon = Icons.view_column;
        break;
      case GalleryGridPreviewMode.thumb:
        modeLabel = '缩略';
        modeIcon = Icons.grid_on;
        break;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(_isSelectionMode 
            ? '已选择 ${_selectedIds.length} 项' 
            : '媒体文件 ($columns列 · $modeLabel)'),
        actions: [
          // 模式切换
          IconButton(
            icon: Icon(modeIcon),
            tooltip: '切换模式 (当前: $modeLabel)',
            onPressed: () {
              ref.read(galleryGridPreviewModeNotifierProvider.notifier).cycleMode();
            },
          ),
          // 缩小 (增加列数)
          IconButton(
            icon: const Icon(Icons.zoom_out),
            tooltip: '缩小',
            onPressed: () {
              ref.read(galleryGridColumnsProvider.notifier).zoomOut();
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
              WidgetsBinding.instance.addPostFrameCallback((_) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToCurrentIndex();
                });
              });
            },
          ),
          if (_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.select_all),
              tooltip: '全选',
              onPressed: () => _selectAll(assetsAsync.valueOrNull ?? []),
            ),
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

          _performInitialScrollIfNeeded();

          switch (previewMode) {
            case GalleryGridPreviewMode.thumb:
              return _buildThumbGrid(assets, columns, currentMedia);
            case GalleryGridPreviewMode.preview:
              return _buildPreviewGrid(assets, columns, currentMedia);
            case GalleryGridPreviewMode.waterfall:
              return _buildWaterfallGrid(assets, columns, currentMedia);
          }
        },
      ),
      bottomNavigationBar: _isSelectionMode && _selectedIds.isNotEmpty
          ? _buildBottomBar()
          : null,
    );
  }

  /// 构建方形缩略图网格（原有模式）
  Widget _buildThumbGrid(List<MediaAsset> assets, int columns, MediaAsset? currentMedia) {
    return _DraggableScrollWrapper(
      scrollController: _scrollController,
      itemCount: assets.length,
      crossAxisCount: columns,
      child: GridView.builder(
        scrollCacheExtent: ScrollCacheExtent.pixels(500),
        controller: _scrollController,
        padding: const EdgeInsets.all(2),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemCount: assets.length,
        itemBuilder: (context, index) {
          final asset = assets[index];
          return _GridTile(
            key: ValueKey(asset.id),
            asset: asset,
            isSelected: _selectedIds.contains(asset.id),
            isCurrent: currentMedia?.id == asset.id,
            selectionIndex: _selectionOrder.indexOf(asset.id),
            isSelectionMode: _isSelectionMode,
            onTap: () => _handleTap(asset, index),
            onLongPress: () => _handleLongPress(asset),
            mode: GalleryGridPreviewMode.thumb,
          );
        },
      ),
    );
  }

  /// 构建预览图网格（等宽不等高，contain 填充，约束宽高比）
  Widget _buildPreviewGrid(List<MediaAsset> assets, int columns, MediaAsset? currentMedia) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - _kScrollbarReservedWidth - 4;
        final itemWidth = (availableWidth - (columns - 1) * 2) / columns;

        // 预计算所有 item 的估算高度
        final itemHeights = assets.map((a) => _estimateItemHeight(a, itemWidth)).toList();

        return _DraggableScrollWrapper(
          scrollController: _scrollController,
          itemCount: assets.length,
          crossAxisCount: columns,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(2),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final rowStart = index * columns;
                      if (rowStart >= assets.length) return const SizedBox.shrink();

                      final rowEnd = (rowStart + columns).clamp(0, assets.length);
                      final rowAssets = assets.sublist(rowStart, rowEnd);
                      final itemCount = rowAssets.length;

                      // 计算本行最大高度（统一行高以对齐）
                      double rowHeight = 0;
                      for (int i = rowStart; i < rowEnd; i++) {
                        if (itemHeights[i] > rowHeight) rowHeight = itemHeights[i];
                      }

                      return SizedBox(
                        height: rowHeight,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: List.generate(itemCount, (i) {
                            final asset = rowAssets[i];
                            final globalIndex = rowStart + i;
                            return SizedBox(
                              width: itemWidth,
                              child: Padding(
                                padding: EdgeInsets.only(right: i < itemCount - 1 ? 2 : 0),
                                child: _GridTile(
                                  key: ValueKey(asset.id),
                                  asset: asset,
                                  isSelected: _selectedIds.contains(asset.id),
                                  isCurrent: currentMedia?.id == asset.id,
                                  selectionIndex: _selectionOrder.indexOf(asset.id),
                                  isSelectionMode: _isSelectionMode,
                                  onTap: () => _handleTap(asset, globalIndex),
                                  onLongPress: () => _handleLongPress(asset),
                                  mode: GalleryGridPreviewMode.preview,
                                  itemWidth: itemWidth,
                                  itemHeight: rowHeight,
                                ),
                              ),
                            );
                          }),
                        ),
                      );
                    },
                    childCount: (assets.length / columns).ceil(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建瀑布流（等宽不等高，自动流入最短列）
  Widget _buildWaterfallGrid(List<MediaAsset> assets, int columns, MediaAsset? currentMedia) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - _kScrollbarReservedWidth - 4;
        final itemWidth = (availableWidth - (columns - 1) * 2) / columns;

        // 计算每个资源的预估高度（基于默认宽高比）
        final itemHeights = assets.map((a) => _estimateItemHeight(a, itemWidth)).toList();

        // 瀑布流布局：分配每个 item 到最短列
        final columnHeights = List<double>.filled(columns, 0);
        final columnAssignments = List<int>.filled(assets.length, 0);
        for (int i = 0; i < assets.length; i++) {
          int shortestCol = 0;
          for (int c = 1; c < columns; c++) {
            if (columnHeights[c] < columnHeights[shortestCol]) {
              shortestCol = c;
            }
          }
          columnAssignments[i] = shortestCol;
          columnHeights[shortestCol] += itemHeights[i] + 2; // +2 for spacing
        }

        return _DraggableScrollWrapper(
          scrollController: _scrollController,
          itemCount: assets.length,
          crossAxisCount: columns,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(2),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(columns, (col) {
                      final colItems = <Widget>[];
                      double yOffset = 0;
                      for (int i = 0; i < assets.length; i++) {
                        if (columnAssignments[i] == col) {
                          final asset = assets[i];
                          colItems.add(
                            Padding(
                              padding: EdgeInsets.only(top: yOffset > 0 ? 2 : 0),
                              child: _GridTile(
                                key: ValueKey(asset.id),
                                asset: asset,
                                isSelected: _selectedIds.contains(asset.id),
                                isCurrent: currentMedia?.id == asset.id,
                                selectionIndex: _selectionOrder.indexOf(asset.id),
                                isSelectionMode: _isSelectionMode,
                                onTap: () => _handleTap(asset, i),
                                onLongPress: () => _handleLongPress(asset),
                                mode: GalleryGridPreviewMode.waterfall,
                                itemWidth: itemWidth,
                                itemHeight: itemHeights[i],
                              ),
                            ),
                          );
                          yOffset += itemHeights[i] + 2;
                        }
                      }
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: col < columns - 1 ? 2 : 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: colItems,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 估算一个媒体项的显示高度（基于默认宽高比，约束在 [0.5, 2.0] 内）
  double _estimateItemHeight(MediaAsset asset, double itemWidth) {
    double aspectRatio = 1.0; // 默认正方形

    if (asset.isVideo) {
      aspectRatio = 9.0 / 16.0; // 视频默认竖屏
    }

    // 约束宽高比
    aspectRatio = aspectRatio.clamp(_kMinAspectRatio, _kMaxAspectRatio);

    // 在预览/瀑布模式下，contain 填充 → 高度 = 宽度 / 宽高比
    // 但 contain 会留空 → 实际内容高度可能小于 tile 高度
    // 这里 tile 高度即为内容最大可能高度
    return itemWidth / aspectRatio;
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

      // 批量标记删除（一次状态更新）
      final ids = _selectedIds.toList();
      await ref.read(mediaAssetListProvider.notifier).batchMarkDeleted(ids, deleted: true);

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

    // 批量恢复（一次状态更新）
    final ids = _selectedIds.toList();
    await ref.read(mediaAssetListProvider.notifier).batchMarkDeleted(ids, deleted: false);

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

/// 网格项 - 使用 StatefulWidget 避免每次重建时重新加载缩略图/预览图
class _GridTile extends ConsumerStatefulWidget {
  final MediaAsset asset;
  final bool isSelected;
  final bool isCurrent;
  final int? selectionIndex;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final GalleryGridPreviewMode mode;
  final double? itemWidth;
  final double? itemHeight;

  const _GridTile({
    super.key,
    required this.asset,
    required this.isSelected,
    required this.isCurrent,
    this.selectionIndex,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
    this.mode = GalleryGridPreviewMode.thumb,
    this.itemWidth,
    this.itemHeight,
  });

  @override
  ConsumerState<_GridTile> createState() => _GridTileState();
}

class _GridTileState extends ConsumerState<_GridTile> {
  File? _imageFile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant _GridTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id || oldWidget.mode != widget.mode) {
      _loadImage();
    }
  }

  /// 加载图片文件（根据模式选择缩略图或预览图）
  Future<void> _loadImage() async {
    final cacheKey = '${widget.mode.name}_${widget.asset.thumbPath ?? widget.asset.filePath}';

    // 检查缓存
    if (_thumbnailCache.containsKey(cacheKey)) {
      if (mounted) {
        setState(() {
          _imageFile = _thumbnailCache[cacheKey];
          _isLoading = false;
        });
      }
      return;
    }

    final storage = ref.read(galleryStorageProvider);
    File? file;

    // 预览/瀑布模式优先加载预览图
    if (widget.mode != GalleryGridPreviewMode.thumb && widget.asset.previewPath != null) {
      file = await storage.getPreviewFile(widget.asset.previewPath!);
    }

    // 回退到缩略图
    if (file == null && widget.asset.thumbPath != null) {
      file = await storage.getThumbFile(widget.asset.thumbPath!);
    }

    // 缓存结果
    _thumbnailCache[cacheKey] = file;

    if (mounted) {
      setState(() {
        _imageFile = file;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool usePreview = widget.mode != GalleryGridPreviewMode.thumb;

    // 预览模式下的 tile 高度：优先使用外部传入的固定高度，否则用默认估算
    double? effectiveHeight = widget.itemHeight;
    if (effectiveHeight == null && usePreview && widget.itemWidth != null) {
      effectiveHeight = widget.itemWidth! / _kMaxAspectRatio;
    }

    Widget tileContent = Stack(
      fit: StackFit.expand,
          children: [
            // 图片内容
            if (_isLoading)
              _buildPlaceholder(usePreview: usePreview, height: effectiveHeight)
            else if (_imageFile != null)
              usePreview
                  ? _buildPreviewContent(effectiveHeight)
                  : Image.file(
                      _imageFile!,
                      fit: BoxFit.cover,
                      cacheWidth: 150,
                      cacheHeight: 150,
                      errorBuilder: (context, error, stack) =>
                          _buildPlaceholder(usePreview: false),
                    )
            else
              _buildPlaceholder(usePreview: usePreview, height: effectiveHeight),

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
                            widget.selectionIndex != null
                                ? '${widget.selectionIndex! + 1}'
                                : '✓',
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
        );

    // 预览/瀑布模式下需要显式高度约束，否则 StackFit.expand 会拿到无限高度
    if (effectiveHeight != null) {
      tileContent = SizedBox(height: effectiveHeight, child: tileContent);
    }

    return RepaintBoundary(
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.asset.isDeleted ? () => _undoDelete() : null,
        onLongPress: widget.onLongPress,
        child: tileContent,
      ),
    );
  }

  /// 构建预览模式内容（contain 填充 + 上下留空）
  Widget _buildPreviewContent(double? minHeight) {
    return Container(
      color: Colors.grey[900],
      constraints: minHeight != null ? BoxConstraints(minHeight: minHeight) : null,
      child: Image.file(
        _imageFile!,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stack) =>
            _buildPlaceholder(usePreview: true, height: minHeight),
      ),
    );
  }

  Future<void> _undoDelete() async {
    await ref.read(mediaAssetListProvider.notifier).markDeleted(widget.asset.id, deleted: false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已恢复: ${widget.asset.filePath.split('/').last}'),
          duration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  Widget _buildPlaceholder({bool usePreview = false, double? height}) {
    return Container(
      color: Colors.grey[800],
      constraints: usePreview && height != null
          ? BoxConstraints(minHeight: height)
          : null,
      child: const Center(
        child: Icon(Icons.image, color: Colors.white30, size: 32),
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