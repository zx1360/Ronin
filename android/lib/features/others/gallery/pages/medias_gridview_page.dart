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

/// 媒体文件网格视图组件
/// - 呈现图片/视频的缩略图 (对应 thumb_path)
/// - 初始一行四个, 可上下滚动
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
    // 获取当前媒体
    final currentMedia = ref.read(currentMediaAssetProvider);
    if (currentMedia == null) return;
    
    // 在 mediaAssetListProvider 中找到当前媒体的位置
    final allAssets = ref.read(mediaAssetListProvider).valueOrNull ?? [];
    final indexInAll = allAssets.indexWhere((a) => a.id == currentMedia.id);
    
    if (indexInAll < 0 || allAssets.isEmpty) return;
    if (!_scrollController.hasClients) return;
    
    final columns = ref.read(galleryGridColumnsProvider);
    
    // 计算目标行
    final row = indexInAll ~/ columns;
    // 计算每个格子的高度 (假设正方形)
    // GridView 内边距: EdgeInsets.all(2) → 左右各 2 → 总计 4
    // _DraggableScrollWrapper 右侧留白: _kScrollbarReservedWidth (12)
    final screenWidth = MediaQuery.of(context).size.width;
    final itemSize = (screenWidth - _kScrollbarReservedWidth - 4 - (columns - 1) * 2) / columns;
    final targetOffset = row * (itemSize + 2); // 加上主轴承间距
    
    // 获取最大滚动范围
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
            : '媒体文件 ($columns列)'),
        actions: [
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

          return _DraggableScrollWrapper(
            scrollController: _scrollController,
            itemCount: assets.length,
            crossAxisCount: columns,
            child: GridView.builder(
              scrollCacheExtent: ScrollCacheExtent.pixels(500), controller: _scrollController,
              padding: const EdgeInsets.all(2),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),
              itemCount: assets.length,
              itemBuilder: (context, index) {
                final asset = assets[index];
                final isSelected = _selectedIds.contains(asset.id);
                // 用 ID 判断是否为当前文件，而不是索引
                final isCurrent = currentMedia?.id == asset.id;
                final selectionIndex = _selectionOrder.indexOf(asset.id);

                return _GridTile(
                  key: ValueKey(asset.id), // 使用 Key 保持 widget 状态
                  asset: asset,
                  isSelected: isSelected,
                  isCurrent: isCurrent,
                  selectionIndex: selectionIndex >= 0 ? selectionIndex + 1 : null,
                  isSelectionMode: _isSelectionMode,
                  onTap: () => _handleTap(asset, index),
                  onLongPress: () => _handleLongPress(asset),
                );
              },
            ),
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