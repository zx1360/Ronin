import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/providers/gallery_providers.dart';

part '../widgets/browser/scroll_wrapper.dart';
part '../widgets/browser/grid_tile.dart';
part '../widgets/browser/intrinsic_height_capped.dart';
part '../widgets/browser/proportional_cell.dart';
part '../widgets/browser/waterfall_cell.dart';
part '../widgets/browser/bottom_button.dart';

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
