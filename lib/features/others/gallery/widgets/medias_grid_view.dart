/// Gallery 媒体网格视图组件
library;

import 'dart:io';
import 'package:flutter/material.dart';

import 'package:torrid/features/others/gallery/models/media_asset.dart';

class MediaGridView extends StatelessWidget {
  final List<MediaAsset> medias;
  final Set<String> selectedIds;
  final bool selectionMode;
  final void Function(String mediaId)? onTap;
  final void Function(String mediaId)? onLongPress;
  final int crossAxisCount;
  final double spacing;

  const MediaGridView({
    super.key,
    required this.medias,
    this.selectedIds = const {},
    this.selectionMode = false,
    this.onTap,
    this.onLongPress,
    this.crossAxisCount = 3,
    this.spacing = 2,
  });

  @override
  Widget build(BuildContext context) {
    if (medias.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('暂无媒体文件', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(spacing),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
      ),
      itemCount: medias.length,
      itemBuilder: (context, index) {
        final media = medias[index];
        final isSelected = selectedIds.contains(media.id);

        return MediaGridItem(
          media: media,
          isSelected: isSelected,
          selectionMode: selectionMode,
          onTap: () => onTap?.call(media.id),
          onLongPress: () => onLongPress?.call(media.id),
        );
      },
    );
  }
}

/// 单个媒体网格项
class MediaGridItem extends StatelessWidget {
  final MediaAsset media;
  final bool isSelected;
  final bool selectionMode;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const MediaGridItem({
    super.key,
    required this.media,
    this.isSelected = false,
    this.selectionMode = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 缩略图
          _buildThumbnail(),

          // 视频标识
          if (media.isVideo) _buildVideoIndicator(),

          // 捆绑标识 (组主文件)
          if (media.isGroupLead) _buildBundleIndicator(),

          // 选中状态遮罩
          if (selectionMode) _buildSelectionOverlay(colorScheme),
        ],
      ),
    );
  }

  Widget _buildThumbnail() {
    final thumbPath = media.thumbPath;
    if (thumbPath != null && thumbPath.isNotEmpty) {
      // 动态拼接本地完整路径
      // final localPath = GalleryFileService().getLocalThumbPath(thumbPath);
      final localPath = "";
      final file = File(localPath);
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: Icon(
        media.isVideo ? Icons.videocam : Icons.image,
        color: Colors.grey[600],
      ),
    );
  }

  Widget _buildVideoIndicator() {
    return Positioned(
      right: 4,
      bottom: 4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(Icons.play_arrow, color: Colors.white, size: 16),
      ),
    );
  }

  Widget _buildBundleIndicator() {
    return Positioned(
      left: 4,
      bottom: 4,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(Icons.layers, color: Colors.white, size: 14),
      ),
    );
  }

  Widget _buildSelectionOverlay(ColorScheme colorScheme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: isSelected ? colorScheme.primary.withOpacity(0.3) : null,
        border: isSelected
            ? Border.all(color: colorScheme.primary, width: 3)
            : null,
      ),
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            isSelected ? Icons.check_circle : Icons.circle_outlined,
            color: isSelected ? colorScheme.primary : Colors.white70,
            size: 24,
          ),
        ),
      ),
    );
  }
}
