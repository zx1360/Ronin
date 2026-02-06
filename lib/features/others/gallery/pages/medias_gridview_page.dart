import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/providers/gallery_providers.dart';
import 'package:torrid/features/others/gallery/services/gallery_storage_service.dart';

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
    final screenWidth = MediaQuery.of(context).size.width;
    final itemSize = (screenWidth - 4 - (columns - 1) * 2) / columns; // padding + spacing
    final targetOffset = row * (itemSize + 2); // 加上间距
    
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

          return GridView.builder(
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
              final isSelected = _selectedIds.contains(asset.id);
              // 用 ID 判断是否为当前文件，而不是索引
              final isCurrent = currentMedia?.id == asset.id;
              final selectionIndex = _selectionOrder.indexOf(asset.id);

              return _GridTile(
                asset: asset,
                isSelected: isSelected,
                isCurrent: isCurrent,
                selectionIndex: selectionIndex >= 0 ? selectionIndex + 1 : null,
                isSelectionMode: _isSelectionMode,
                onTap: () => _handleTap(asset, index),
                onLongPress: () => _handleLongPress(asset),
              );
            },
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
      // 如果文件已删除，提示用户先恢复
      if (asset.isDeleted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('该文件已删除，请先恢复'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
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

/// 网格项
class _GridTile extends ConsumerWidget {
  final MediaAsset asset;
  final bool isSelected;
  final bool isCurrent;
  final int? selectionIndex;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _GridTile({
    required this.asset,
    required this.isSelected,
    required this.isCurrent,
    this.selectionIndex,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(galleryStorageProvider);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 缩略图 (优先缩略图, fallback 到原图)
          FutureBuilder<File?>(
            future: _getThumbnailFile(storage),
            builder: (context, snapshot) {
              if (snapshot.data != null) {
                return Image.file(
                  snapshot.data!,
                  fit: BoxFit.cover,
                  cacheWidth: 200, // 限制缓存尺寸，提高性能
                  errorBuilder: (context, error, stack) =>
                      _buildPlaceholder(),
                );
              }
              return _buildPlaceholder();
            },
          ),

          // 选中边框
          if (isSelected)
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 3,
                ),
              ),
            ),

          // 当前浏览位置指示
          if (isCurrent && !isSelectionMode)
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

          // 选择模式下的勾选框
          if (isSelectionMode)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.black54,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: isSelected
                    ? Center(
                        child: Text(
                          selectionIndex?.toString() ?? '✓',
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
          if (asset.isDeleted)
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
          if (asset.groupId != null)
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
          if (asset.isVideo)
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
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[800],
      child: Icon(
        asset.isVideo ? Icons.videocam : Icons.image,
        color: Colors.grey[600],
      ),
    );
  }

  /// 获取缩略图文件 (优先缩略图, fallback 到原图)
  Future<File?> _getThumbnailFile(GalleryStorageService storage) async {
    // 优先使用缩略图
    if (asset.thumbPath != null) {
      final thumbFile = await storage.getThumbFile(asset.thumbPath!);
      if (thumbFile != null) return thumbFile;
    }
    
    // 没有缩略图则使用原图
    return await storage.getMediaFile(asset.filePath);
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