import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/providers/gallery_providers.dart';
import 'package:torrid/features/others/gallery/services/gallery_preview_catalog.dart';
import 'package:torrid/features/others/gallery/widgets/browser/media_grid_layout.dart';
import 'package:torrid/features/others/services/media_share_service.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

part '../widgets/browser/scroll_wrapper.dart';
part '../widgets/browser/grid_tile.dart';
part '../widgets/browser/bottom_button.dart';
part '../widgets/browser/batch_actions.dart';
part '../widgets/browser/layouts.dart';

/// 快速滚动条轨道宽度
const double _kScrollbarTrackWidth = 8;

/// 媒体总览：切换预览、列数和批量标记。
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

  final _scrollController = ScrollController(keepScrollOffset: false);
  var _previewCatalog = GalleryPreviewCatalog();
  List<MediaAsset>? _previewAssets;
  Future<Map<String, GalleryPreview>>? _previewFuture;
  MediaGridLayout? _previewLayout;
  Object? _layoutKey;
  double _gridWidth = 0;
  bool _hasScrolledToInitial = false;
  bool _userHasScrolled = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentIndex({bool animate = true}) {
    if (!_scrollController.hasClients) return;
    final assets = ref.read(galleryBrowsingAssetsProvider).value ?? [];
    final current = ref.read(currentMediaAssetProvider);
    final index = assets.indexWhere((a) => a.id == current?.id);
    if (index < 0) return;
    final mode = ref.read(galleryGridPreviewModeProvider);
    final columns = ref.read(galleryGridColumnsProvider);
    final cellWidth = (_gridWidth - (columns - 1) * 2) / columns;
    final offset = mode == GalleryGridPreviewMode.thumb
        ? (index ~/ columns) * (cellWidth + 2)
        : _previewLayout?.getGeometryForChildIndex(index).scrollOffset ?? 0.0;
    final target = offset.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    if (animate) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(target);
    }
  }

  void _performInitialScrollIfNeeded() {
    if (_hasScrolledToInitial) return;
    _hasScrolledToInitial = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_userHasScrolled) _scrollToCurrentIndex(animate: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(galleryFilesRevisionProvider, (_, _) {
      setState(() {
        _previewCatalog = GalleryPreviewCatalog();
        _previewAssets = null;
      });
    });
    // 使用包含已删除文件的列表
    final assetsAsync = ref.watch(galleryBrowsingAssetsProvider);
    final columns = ref.watch(galleryGridColumnsProvider);
    // 获取当前媒体的 ID，而不是索引
    final currentMedia = ref.watch(currentMediaAssetProvider);
    final mode = ref.watch(galleryGridPreviewModeProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          _isSelectionMode
              ? '已选择 ${_selectedIds.length} 项'
              : _buildTitle(columns),
          style: const TextStyle(fontSize: 16),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (!_isSelectionMode) ...[
            // 预览模式切换
            PopupMenuButton<GalleryGridPreviewMode>(
              icon: const Icon(Icons.grid_view, size: 20),
              tooltip: '预览模式：${_modeLabel(mode)}',
              initialValue: mode,
              color: const Color(0xFF24252A),
              surfaceTintColor: Colors.transparent,
              position: PopupMenuPosition.under,
              onSelected: (mode) {
                if (mode == ref.read(galleryGridPreviewModeProvider)) {
                  return;
                }
                _hasScrolledToInitial = false;
                _userHasScrolled = false;
                ref
                    .read(galleryGridPreviewModeProvider.notifier)
                    .setMode(mode);
              },
              itemBuilder: (context) {
                final current = ref.watch(
                  galleryGridPreviewModeProvider,
                );
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
                          color: mode == current
                              ? Colors.amber
                              : Colors.white54,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _modeLabel(mode),
                          style: TextStyle(
                            color: mode == current
                                ? Colors.amber
                                : Colors.white,
                            fontWeight: mode == current
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
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
                _hasScrolledToInitial = false;
                _userHasScrolled = false;
                ref.read(galleryGridColumnsProvider.notifier).zoomOut();
              },
            ),
            // 放大 (减少列数)
            IconButton(
              icon: const Icon(Icons.zoom_in),
              tooltip: '放大',
              onPressed: () {
                _hasScrolledToInitial = false;
                _userHasScrolled = false;
                ref.read(galleryGridColumnsProvider.notifier).zoomIn();
              },
            ),
          ],
          if (_isSelectionMode) ...[
            // 全选/取消全选
            IconButton(
              icon: const Icon(Icons.select_all),
              tooltip: '全选',
              onPressed: () => _selectAll(assetsAsync.value ?? []),
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

          final taggedIds =
              ref.watch(mediaIdsWithTagsProvider).value ??
              const <String>{};
          if (mode != GalleryGridPreviewMode.thumb &&
              !identical(_previewAssets, assets)) {
            _previewAssets = assets;
            _previewFuture = _previewCatalog.load(
              assets,
              ref.read(galleryStorageProvider),
            );
          }
          Widget grid(Map<String, GalleryPreview> previews) =>
              _DraggableScrollWrapper(
                scrollController: _scrollController,
                child: NotificationListener<ScrollStartNotification>(
                  onNotification: (notification) {
                    if (notification.dragDetails != null) {
                      _userHasScrolled = true;
                    }
                    return false;
                  },
                  child: _buildMediaGrid(
                    assets,
                    columns,
                    mode,
                    currentMedia,
                    taggedIds,
                    previews,
                  ),
                ),
              );
          if (mode == GalleryGridPreviewMode.thumb) return grid(const {});
          return FutureBuilder<Map<String, GalleryPreview>>(
            future: _previewFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: TextButton(
                    onPressed: () => setState(() {
                      _previewFuture = _previewCatalog.load(
                        assets,
                        ref.read(galleryStorageProvider),
                      );
                    }),
                    child: const Text('预览读取失败，点击重试'),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }
              return grid(snapshot.data!);
            },
          );
        },
      ),
      bottomNavigationBar: _isSelectionMode && _selectedIds.isNotEmpty
          ? _buildBottomBar()
          : null,
    );
  }

  Future<void> _handleTap(MediaAsset asset, int index) async {
    if (_isSelectionMode) {
      _toggleSelection(asset.id);
    } else {
      // 如果文件已删除，双击取消删除 (通过 onDoubleTap 回调处理)
      if (asset.isDeleted) {
        return; // 不跳转，由 _GridTile 的双击处理恢复
      }

      // 通过 CurrentMediaAsset 跳转，以支持标签继承等功能
      try {
        await ref.read(currentMediaAssetProvider.notifier).jumpTo(index);
        if (mounted) Navigator.pop(context);
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('切换失败：$error')));
        }
      }
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
    final mode = ref.read(galleryGridPreviewModeProvider);
    final prefix = ref.read(galleryActiveGroupProvider) == null ? '' : '组内 · ';
    return '$prefix${_modeLabel(mode)} ($columns列)';
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
