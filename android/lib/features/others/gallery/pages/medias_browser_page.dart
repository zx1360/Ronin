import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/providers/gallery_providers.dart';
import 'package:torrid/features/others/services/media_share_service.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

part '../widgets/browser/scroll_wrapper.dart';
part '../widgets/browser/grid_tile.dart';
part '../widgets/browser/intrinsic_height_capped.dart';
part '../widgets/browser/proportional_cell.dart';
part '../widgets/browser/waterfall_cell.dart';
part '../widgets/browser/bottom_button.dart';
part '../widgets/browser/batch_actions.dart';
part '../widgets/browser/layouts.dart';

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
  bool _working = false;

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

  /// 用户是否已手动滚动（用于取消自动定位重试）
  bool _userHasScrolled = false;

  /// 是否正在执行自动滚动定位（用于取消重试链路）
  bool _isAutoScrolling = false;

  /// 检测用户手动滚动（拖拽手势），立即取消自动定位
  bool _onUserScrollStart(ScrollStartNotification notification) {
    if (notification.dragDetails != null) {
      _userHasScrolled = true;
      _isAutoScrolling = false;
    }
    // 返回 false 允许通知继续冒泡
    return false;
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
  /// 若目标项尚未被懒加载构建（offscreen），回退到自适应估算偏移量，
  /// 渐进逼近目标。用户手动滚动后将自动取消所有待处理重试。
  void _scrollToCurrentIndex({bool animate = true}) {
    final currentMedia = ref.read(currentMediaAssetProvider);
    if (currentMedia == null) return;
    final allAssets = ref.read(mediaAssetListProvider).valueOrNull ?? [];
    final indexInAll = allAssets.indexWhere((a) => a.id == currentMedia.id);
    if (indexInAll < 0) return;

    // 允许新一轮自动定位
    _userHasScrolled = false;
    _isAutoScrolling = true;

    _tryScrollToCurrent(
      animate: animate,
      fallbackIndex: indexInAll,
      retriesLeft: 5,
    );
  }

  /// 带重试的滚动定位
  ///
  /// 缩略模式：行高固定，一次估算 + [jumpTo] 即可精准命中。
  /// 等比模式：行高因 [IntrinsicHeight] 不定，首跳使用平均高度估算；
  /// 若未命中则按视口增量朝目标方向渐进逼近。
  /// 瀑布流模式：首跳估算后逐帧检查目标是否已构建。
  ///
  /// 所有模式一旦检测到用户手动滚动 ([_userHasScrolled])，立即放弃重试。
  void _tryScrollToCurrent({
    required bool animate,
    required int fallbackIndex,
    required int retriesLeft,
  }) {
    // 用户已手动滚动 或 自动定位已被取消，立即退出
    if (_userHasScrolled || !_isAutoScrolling) return;
    if (retriesLeft <= 0) {
      _isAutoScrolling = false;
      return;
    }

    final ctx = _currentItemKey.currentContext;
    if (ctx != null) {
      // 精确定位
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.0,
        duration: animate ? const Duration(milliseconds: 300) : Duration.zero,
        curve: Curves.easeOut,
      );
      // 瀑布流同步
      if (_waterfallColumnControllers.isNotEmpty) {
        Future.delayed(
          animate ? const Duration(milliseconds: 350) : Duration.zero,
          () {
            if (mounted) _syncWaterfallAfterEnsureVisible();
          },
        );
      }
      _isAutoScrolling = false;
      return;
    }

    // 回退: 基于当前模式的估算偏移量滚动到目标附近
    final mode = ref.read(galleryGridPreviewModeNotifierProvider);
    final columns = ref.read(galleryGridColumnsProvider);
    final cellW = _cellWidth(columns);
    double targetOffset;

    switch (mode) {
      case GalleryGridPreviewMode.thumb:
        // 缩略模式行高固定 (cellW + 2)，一次估算即可精准命中
        final row = fallbackIndex ~/ columns;
        targetOffset = row * (cellW + 2);
        break;
      case GalleryGridPreviewMode.preview:
        // 等比模式行高因 IntrinsicHeight 而不定：
        // 使用 maxScrollExtent 比例锚点（与具体行高无关），
        // 重试时朝锚点方向视口级渐进，逼近后 snap 到精确比例位。
        if (_scrollController.hasClients) {
          final pos = _scrollController.position;
          final maxScroll = pos.maxScrollExtent;
          final allAssets = ref.read(mediaAssetListProvider).valueOrNull;
          final totalItems = allAssets?.length ?? 0;
          if (maxScroll > 0 && totalItems > 0) {
            final ratioTarget = (fallbackIndex / totalItems) * maxScroll;
            if (retriesLeft < 5) {
              final currentOffset = pos.pixels;
              final viewport = pos.viewportDimension;
              if ((currentOffset - ratioTarget).abs() < viewport * 0.3) {
                targetOffset = ratioTarget;
              } else if (currentOffset < ratioTarget) {
                targetOffset = currentOffset + viewport * 0.7;
              } else {
                targetOffset = currentOffset - viewport * 0.7;
              }
            } else {
              targetOffset = ratioTarget;
            }
          } else {
            final row = fallbackIndex ~/ columns;
            targetOffset = row * (cellW * 0.75 + 2);
          }
        } else {
          final row = fallbackIndex ~/ columns;
          targetOffset = row * (cellW * 0.75 + 2);
        }
        break;
      case GalleryGridPreviewMode.waterfall:
        final itemsInCol = (fallbackIndex / columns).ceil();
        targetOffset = itemsInCol * (cellW * 0.75 + 2);
        if (_scrollController.hasClients) {
          final clamped = targetOffset.clamp(
            0.0,
            _scrollController.position.maxScrollExtent,
          );
          _scrollController.jumpTo(clamped);
        }
        for (final ctrl in _waterfallColumnControllers) {
          if (ctrl.hasClients) {
            ctrl.jumpTo(targetOffset.clamp(0.0, ctrl.position.maxScrollExtent));
          }
        }
        // 检查是否需要继续重试
        if (_userHasScrolled || !_isAutoScrolling) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _tryScrollToCurrent(
              animate: false,
              fallbackIndex: fallbackIndex,
              retriesLeft: retriesLeft - 1,
            );
          }
        });
        return;
    }

    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(targetOffset.clamp(0.0, maxScroll));
    }

    // 检查是否需要继续重试
    if (_userHasScrolled || !_isAutoScrolling) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _tryScrollToCurrent(
          animate: false,
          fallbackIndex: fallbackIndex,
          retriesLeft: retriesLeft - 1,
        );
      }
    });
  }

  /// 在内容首次渲染后执行初始滚动 — 通过重试机制等待目标项构建完成
  void _performInitialScrollIfNeeded() {
    if (_hasScrolledToInitial) return;
    _hasScrolledToInitial = true;

    // 使用重试机制：每帧尝试精确定位，直到成功或重试耗尽
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
        title: Text(
          _isSelectionMode
              ? '已选择 ${_selectedIds.length} 项'
              : _buildTitle(columns),
        ),
        actions: [
          // 预览模式切换
          PopupMenuButton<GalleryGridPreviewMode>(
            icon: const Icon(Icons.grid_view, size: 20),
            tooltip: '预览模式',
            onSelected: (mode) {
              ref
                  .read(galleryGridPreviewModeNotifierProvider.notifier)
                  .setMode(mode);
              _hasScrolledToInitial = false;
              // 单帧延迟后触发，内部重试机制负责精确定位
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _scrollToCurrentIndex();
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
                        mode == current
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
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
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _scrollToCurrentIndex();
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
                _scrollToCurrentIndex();
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
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (error, stack) => Center(
          child: Text(
            '加载失败: $error',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        data: (assets) {
          if (assets.isEmpty) {
            return const Center(
              child: Text('暂无媒体文件', style: TextStyle(color: Colors.grey)),
            );
          }

          // 数据加载完成后执行初始滚动
          _performInitialScrollIfNeeded();

          // 获取有关联标签的媒体 ID 集合（用于标签指示器）
          final taggedIds =
              ref.watch(mediaIdsWithTagsProvider).valueOrNull ?? const {};

          final mode = ref.watch(galleryGridPreviewModeNotifierProvider);

          // 根据预览模式构建不同的布局
          Widget gridChild;
          switch (mode) {
            case GalleryGridPreviewMode.thumb:
              gridChild = _buildThumbGrid(
                assets,
                columns,
                currentMedia,
                taggedIds,
              );
            case GalleryGridPreviewMode.preview:
              gridChild = _buildProportionalGrid(
                assets,
                columns,
                currentMedia,
                taggedIds,
              );
            case GalleryGridPreviewMode.waterfall:
              gridChild = _buildWaterfallGrid(
                assets,
                columns,
                currentMedia,
                taggedIds,
              );
          }

          return _DraggableScrollWrapper(
            scrollController: _scrollController,
            itemCount: assets.length,
            crossAxisCount: columns,
            child: NotificationListener<ScrollStartNotification>(
              onNotification: _onUserScrollStart,
              child: gridChild,
            ),
          );
        },
      ),
      bottomNavigationBar: _isSelectionMode && _selectedIds.isNotEmpty
          ? _buildBottomBar()
          : null,
    );
  }

  void _handleTap(MediaAsset asset, int index) {
    if (_isSelectionMode) {
      _toggleSelection(asset.id);
    } else {
      // 如果文件已删除，双击取消删除 (通过 onDoubleTap 回调处理)
      if (asset.isDeleted) {
        return; // 不跳转，由 _GridTile 的双击处理恢复
      }

      // 通过 CurrentMediaAsset 跳转，以支持标签继承等功能
      ref.read(currentMediaAssetProvider.notifier).jumpTo(index);
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

  Future<void> _runSelectionAction(Future<void> Function() action) async {
    if (_working) return;
    final offset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;
    setState(() => _working = true);
    try {
      await action();
      if (!mounted) return;
      setState(() {
        _isSelectionMode = false;
        _selectedIds.clear();
        _selectionOrder.clear();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.jumpTo(
            offset.clamp(0.0, _scrollController.position.maxScrollExtent),
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('操作失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
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
}
