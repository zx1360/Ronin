import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/services/gallery_storage_service.dart';

/// 网络图片组件 - 使用本地缩略图/预览图作为占位符
/// 支持旋转和缩放
class NetworkImageWidget extends StatefulWidget {
  final String imageUrl;
  final MediaAsset asset;
  final GalleryStorageService storage;
  final int rotationQuarterTurns;
  final Map<String, String> httpHeaders;

  const NetworkImageWidget({
    super.key,
    required this.imageUrl,
    required this.asset,
    required this.storage,
    this.rotationQuarterTurns = 0,
    this.httpHeaders = const {},
  });

  @override
  State<NetworkImageWidget> createState() => _NetworkImageWidgetState();
}

class _NetworkImageWidgetState extends State<NetworkImageWidget> {
  File? _placeholderFile;
  bool _isLoading = true;

  // 用于手动控制缩放和平移
  final TransformationController _transformController =
      TransformationController();

  // 最小/最大缩放
  static const double _minScale = 1.0;
  static const double _maxScale = 4.0;

  @override
  void initState() {
    super.initState();
    _loadPlaceholder();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant NetworkImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id) {
      _loadPlaceholder();
      // 重置变换
      _transformController.value = Matrix4.identity();
    }
    // 旋转变化时也重置变换
    if (oldWidget.rotationQuarterTurns != widget.rotationQuarterTurns) {
      _transformController.value = Matrix4.identity();
    }
  }

  Future<void> _loadPlaceholder() async {
    setState(() {
      _isLoading = true;
    });

    File? file;
    try {
      if (widget.asset.previewPath != null) {
        file = await widget.storage.getPreviewFile(widget.asset.previewPath!);
      }
      if (file == null && widget.asset.thumbPath != null) {
        file = await widget.storage.getThumbFile(widget.asset.thumbPath!);
      }
    } catch (e) {
      // 忽略错误,使用加载指示器
    }

    if (mounted) {
      setState(() {
        _placeholderFile = file;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 使用 RotatedBox + InteractiveViewer 组合
    // RotatedBox 处理布局（交换宽高）
    // InteractiveViewer 处理缩放和平移，其手势在 RotatedBox 内部，坐标系正确
    return Container(
      color: Colors.black,
      child: RotatedBox(
        quarterTurns: widget.rotationQuarterTurns,
        child: CachedNetworkImage(
          imageUrl: widget.imageUrl,
          httpHeaders: widget.httpHeaders,
          imageBuilder: (context, imageProvider) => _buildInteractiveImage(
            imageProvider,
            ValueKey('photo_${widget.asset.id}_${widget.rotationQuarterTurns}'),
          ),
          placeholder: (context, url) => _buildPlaceholderOrLoading(),
          errorWidget: (context, url, error) => _buildErrorOrPlaceholder(),
        ),
      ),
    );
  }

  Widget _buildInteractiveImage(ImageProvider imageProvider, Key key) {
    return InteractiveViewer(
      key: key,
      transformationController: _transformController,
      minScale: _minScale,
      maxScale: _maxScale,
      panEnabled: true,
      scaleEnabled: true,
      // 限制在边界内平移
      boundaryMargin: EdgeInsets.zero,
      constrained: true,
      child: Center(
        child: Image(
          image: imageProvider,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildPlaceholderOrLoading() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_placeholderFile != null) {
      return InteractiveViewer(
        key: ValueKey(
            'placeholder_${widget.asset.id}_${widget.rotationQuarterTurns}'),
        minScale: _minScale,
        maxScale: _maxScale,
        boundaryMargin: EdgeInsets.zero,
        constrained: true,
        child: Center(
          child: Image.file(
            _placeholderFile!,
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    return const Center(
      child: CircularProgressIndicator(color: Colors.white),
    );
  }

  Widget _buildErrorOrPlaceholder() {
    if (_placeholderFile != null) {
      return InteractiveViewer(
        key: ValueKey(
            'error_${widget.asset.id}_${widget.rotationQuarterTurns}'),
        minScale: _minScale,
        maxScale: _maxScale,
        boundaryMargin: EdgeInsets.zero,
        constrained: true,
        child: Center(
          child: Image.file(
            _placeholderFile!,
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error, color: Colors.red, size: 48),
          const SizedBox(height: 8),
          Text(
            '加载失败',
            style: TextStyle(color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}
