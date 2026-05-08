import 'dart:convert';
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
    final cropData = _parseCropData();

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RotatedBox(
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
          // 裁切遮罩覆盖层
          if (cropData != null)
            IgnorePointer(
              child: _CropPreviewOverlay(cropData: cropData),
            ),
        ],
      ),
    );
  }

  /// 解析 edit_params 中的裁切数据（按旋转后坐标处理）
  _CropRect? _parseCropData() {
    final p = widget.asset.editParams;
    if (p == null) return null;
    try {
      final json = jsonDecode(p) as Map<String, dynamic>;
      if (json['type'] != 'image') return null;
      final cl = (json['crop_left'] as num?)?.toDouble();
      final ct = (json['crop_top'] as num?)?.toDouble();
      final cr = (json['crop_right'] as num?)?.toDouble();
      final cb = (json['crop_bottom'] as num?)?.toDouble();
      if (cl == null || ct == null || cr == null || cb == null) return null;
      if (cl <= 0 && ct <= 0 && cr <= 0 && cb <= 0) return null;
      return _CropRect(left: cl, top: ct, right: cr, bottom: cb);
    } catch (_) {}
    return null;
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

/// 裁切数据
class _CropRect {
  final double left, top, right, bottom;
  const _CropRect({required this.left, required this.top, required this.right, required this.bottom});
}

/// 裁切预览叠加层 — 在半透明遮罩上显示裁切框
class _CropPreviewOverlay extends StatelessWidget {
  final _CropRect cropData;
  const _CropPreviewOverlay({required this.cropData});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cw = constraints.maxWidth;
        final ch = constraints.maxHeight;

        // crop 坐标除以原始图片尺寸得到比例（假设原始图比例跨度完整）
        final maxDim = cropData.right > cropData.bottom ? cropData.right : cropData.bottom;
        if (maxDim <= 0) return const SizedBox();

        final ratioW = cw / maxDim;
        final ratioH = ch / maxDim;
        final scale = ratioW < ratioH ? ratioW : ratioH;

        final cl = cropData.left * scale + (cw - maxDim * scale) / 2;
        final ct = cropData.top * scale + (ch - maxDim * scale) / 2;
        final cr = cropData.right * scale + (cw - maxDim * scale) / 2;
        final cb = cropData.bottom * scale + (ch - maxDim * scale) / 2;

        return CustomPaint(
          painter: _CropPreviewPainter(cropRect: Rect.fromLTRB(cl, ct, cr, cb)),
        );
      },
    );
  }
}

class _CropPreviewPainter extends CustomPainter {
  final Rect cropRect;
  _CropPreviewPainter({required this.cropRect});

  @override
  void paint(Canvas canvas, Size size) {
    // 裁掉区域半透明暗色
    final bg = Paint()..color = Colors.black45;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, cropRect.top), bg);
    canvas.drawRect(Rect.fromLTWH(0, cropRect.bottom, size.width, size.height - cropRect.bottom), bg);
    canvas.drawRect(Rect.fromLTWH(0, cropRect.top, cropRect.left, cropRect.height), bg);
    canvas.drawRect(Rect.fromLTWH(cropRect.right, cropRect.top, size.width - cropRect.right, cropRect.height), bg);

    // 保留区白色细边框
    final border = Paint()..color = Colors.white54..style = PaintingStyle.stroke..strokeWidth = 1.5;
    canvas.drawRect(cropRect, border);
  }

  @override
  bool shouldRepaint(_CropPreviewPainter old) => old.cropRect != cropRect;
}
