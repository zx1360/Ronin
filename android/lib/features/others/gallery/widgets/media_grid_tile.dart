import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/providers/gallery_providers.dart';

/// 预览模式下的宽高比约束范围
const double kGalleryMinAspectRatio = 0.5; // 1:2
const double kGalleryMaxAspectRatio = 2.0; // 2:1

/// 缩略图文件缓存 (避免重复的文件系统检查)
final Map<String, File?> _thumbnailCache = {};

/// 网格项组件 — 根据模式加载缩略图或预览图，支持选择/删除/捆绑标记叠加层
class MediaGridTile extends ConsumerStatefulWidget {
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

  const MediaGridTile({
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
  ConsumerState<MediaGridTile> createState() => _MediaGridTileState();
}

class _MediaGridTileState extends ConsumerState<MediaGridTile> {
  File? _imageFile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant MediaGridTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id || oldWidget.mode != widget.mode) {
      _loadImage();
    }
  }

  /// 加载图片文件（模式无关的缓存键，切换模式时复用已加载的文件）
  Future<void> _loadImage() async {
    final bool needPreview = widget.mode != GalleryGridPreviewMode.thumb;
    final cacheKey = needPreview ? 'preview_${widget.asset.id}' : 'thumb_${widget.asset.id}';

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

    if (needPreview && widget.asset.previewPath != null) {
      file = await storage.getPreviewFile(widget.asset.previewPath!);
    }

    if (file == null && widget.asset.thumbPath != null) {
      file = await storage.getThumbFile(widget.asset.thumbPath!);
    }

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
    final bool isWaterfall = widget.mode == GalleryGridPreviewMode.waterfall;

    double? effectiveHeight;
    if (!isWaterfall) {
      effectiveHeight = widget.itemHeight;
      if (effectiveHeight == null && usePreview && widget.itemWidth != null) {
        effectiveHeight = widget.itemWidth! / kGalleryMaxAspectRatio;
      }
    }

    Widget tileContent = Stack(
      fit: isWaterfall ? StackFit.loose : StackFit.expand,
      children: [
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

        if (widget.isSelected)
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 3,
              ),
            ),
          ),

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

        if (widget.asset.isVideo)
          const Positioned(
            bottom: 4,
            right: 4,
            child: Icon(Icons.play_circle_outline, color: Colors.white, size: 24),
          ),
      ],
    );

    if (isWaterfall && widget.itemWidth != null) {
      tileContent = SizedBox(width: widget.itemWidth, child: tileContent);
    } else if (effectiveHeight != null) {
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

  Widget _buildPreviewContent(double? minHeight) {
    return Image.file(
      _imageFile!,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stack) =>
          _buildPlaceholder(usePreview: true, height: minHeight),
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
      color: usePreview ? Colors.transparent : Colors.grey[800],
      constraints: usePreview && height != null ? BoxConstraints(minHeight: height) : null,
      child: const Center(
        child: Icon(Icons.image, color: Colors.white30, size: 32),
      ),
    );
  }
}
