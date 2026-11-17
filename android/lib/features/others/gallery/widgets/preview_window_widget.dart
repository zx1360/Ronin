import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/providers/gallery_providers.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

/// 预览小窗组件 - 显示下一个媒体文件的缩略图
/// 可拖动、点击跳转、无下一个文件时不渲染
class PreviewWindowWidget extends ConsumerStatefulWidget {
  /// 小窗尺寸
  final double size;

  /// 点击回调 - 跳转到下一个文件
  final VoidCallback? onTap;

  /// 旋转角度 (0, 1, 2, 3 表示 0°, 90°, 180°, 270° CW)
  final int rotationQuarterTurns;

  const PreviewWindowWidget({
    super.key,
    this.size = 80,
    this.onTap,
    this.rotationQuarterTurns = 0,
  });

  @override
  ConsumerState<PreviewWindowWidget> createState() =>
      _PreviewWindowWidgetState();
}

class _PreviewWindowWidgetState extends ConsumerState<PreviewWindowWidget> {
  /// 相对于可拖动区域右下角的偏移。
  Offset _position = const Offset(16, 24);

  /// 缩略图文件（本地）
  File? _thumbFile;

  /// 是否正在加载本地缩略图
  bool _isLoadingThumb = false;

  /// 上一个预加载的 asset id
  String? _lastAssetId;

  @override
  Widget build(BuildContext context) {
    final nextAsset = ref.watch(nextMediaAssetProvider);

    if (nextAsset == null) {
      // 清理缩略图状态
      if (_lastAssetId != null) {
        _lastAssetId = null;
        _thumbFile = null;
        _isLoadingThumb = false;
      }
      return const SizedBox.shrink();
    }

    // 预加载本地缩略图
    if (nextAsset.id != _lastAssetId) {
      _lastAssetId = nextAsset.id;
      _loadLocalThumb(nextAsset);
    }

    return _buildDraggableWindow(nextAsset);
  }

  /// 加载本地缩略图
  Future<void> _loadLocalThumb(MediaAsset asset) async {
    if (_isLoadingThumb) return;

    setState(() {
      _isLoadingThumb = true;
      _thumbFile = null;
    });

    final storage = ref.read(galleryStorageProvider);

    try {
      // 优先使用缩略图
      if (asset.thumbPath != null) {
        final file = await storage.getThumbFile(asset.thumbPath!);
        if (file != null && mounted) {
          setState(() {
            _thumbFile = file;
            _isLoadingThumb = false;
          });
          return;
        }
      }

      // 其次使用预览图
      if (asset.previewPath != null) {
        final file = await storage.getPreviewFile(asset.previewPath!);
        if (file != null && mounted) {
          setState(() {
            _thumbFile = file;
            _isLoadingThumb = false;
          });
          return;
        }
      }
    } catch (e) {
      // 忽略错误，使用网络图片
    }

    if (mounted) {
      setState(() {
        _isLoadingThumb = false;
      });
    }
  }

  Widget _buildDraggableWindow(MediaAsset nextAsset) {
    final content = _buildWindowContent(nextAsset);
    return LayoutBuilder(
      builder: (context, constraints) {
        const margin = 8.0;
        final maxRight = constraints.maxWidth - widget.size - margin;
        final maxBottom = constraints.maxHeight - widget.size - margin;
        if (maxRight < margin || maxBottom < margin) {
          return const SizedBox.shrink();
        }
        Offset clamp(Offset position) => Offset(
          position.dx.clamp(margin, maxRight),
          position.dy.clamp(margin, maxBottom),
        );
        final position = clamp(_position);
        return Stack(
          children: [
            Positioned(
              right: position.dx,
              bottom: position.dy,
              child: GestureDetector(
                dragStartBehavior: DragStartBehavior.down,
                onPanUpdate: (details) {
                  final next = clamp(clamp(_position) - details.delta);
                  if (next != _position) setState(() => _position = next);
                },
                onTap: widget.onTap,
                child: content,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWindowContent(MediaAsset nextAsset) {
    return RotatedBox(
      quarterTurns: widget.rotationQuarterTurns,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildThumbnail(nextAsset),
              // 播放图标（视频）
              if (nextAsset.isVideo)
                const Center(
                  child: Icon(
                    Icons.play_circle_outline,
                    color: Colors.white70,
                    size: 28,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(MediaAsset asset) {
    // 优先使用本地缩略图
    if (_thumbFile != null) {
      return Image.file(
        _thumbFile!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _buildNetworkThumbnail(asset),
      );
    }

    // 加载中
    if (_isLoadingThumb) {
      return Container(
        color: Colors.grey[900],
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white38,
            ),
          ),
        ),
      );
    }

    // 使用网络图片（原图作为兜底）
    return _buildNetworkThumbnail(asset);
  }

  Widget _buildNetworkThumbnail(MediaAsset asset) {
    final apiClient = ref.read(apiClientManagerProvider);
    final baseUrl = apiClient.baseUrl;
    final headers = apiClient.headers;

    // 使用缩略图API或原图API
    final imageUrl = galleryMediaUrl(baseUrl, asset, type: 'thumb');

    return CachedNetworkImage(
      imageUrl: imageUrl,
      httpHeaders: headers,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: Colors.grey[900],
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white38,
            ),
          ),
        ),
      ),
      errorWidget: (context, url, error) => _buildFallbackThumbnail(asset),
    );
  }

  /// 兜底方案：使用原图
  Widget _buildFallbackThumbnail(MediaAsset asset) {
    final apiClient = ref.read(apiClientManagerProvider);
    final baseUrl = apiClient.baseUrl;
    final headers = apiClient.headers;

    final imageUrl = galleryMediaUrl(baseUrl, asset);

    return CachedNetworkImage(
      imageUrl: imageUrl,
      httpHeaders: headers,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: Colors.grey[900],
        child: const Center(
          child: Icon(Icons.image, color: Colors.white24, size: 24),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.grey[900],
        child: const Center(
          child: Icon(Icons.broken_image, color: Colors.white24, size: 24),
        ),
      ),
    );
  }
}
