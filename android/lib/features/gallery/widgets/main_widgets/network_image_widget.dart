import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:torrid/features/gallery/models/image_edit.dart';
import 'package:torrid/features/gallery/models/media_asset.dart';
import 'package:torrid/features/gallery/services/gallery_storage_service.dart';

/// 计算图片在容器内的绘制矩形
///
/// - 竖屏容器(宽 < 高): 先按宽度对齐容器; 高度超出则从图片顶部开始显示
///   (由调用方提供纵向拖动), 未超出则垂直居中;
/// - 横屏容器(含应用内旋转 90° 后的显示区域): 保持等比完整显示并居中.
///
/// 图片尺寸未知时退化为铺满容器.
Rect imageDisplayRect(Size viewport, Size? image) {
  if (image == null ||
      image.width <= 0 ||
      image.height <= 0 ||
      viewport.width <= 0 ||
      viewport.height <= 0) {
    return Offset.zero & viewport;
  }

  final aspect = image.width / image.height;
  final widthFit = viewport.width < viewport.height;
  double dw, dh;
  if (widthFit || aspect > viewport.width / viewport.height) {
    dw = viewport.width;
    dh = dw / aspect;
  } else {
    dh = viewport.height;
    dw = dh * aspect;
  }

  final dx = (viewport.width - dw) / 2;
  final overflows = widthFit && dh > viewport.height;
  final dy = overflows ? 0.0 : (viewport.height - dh) / 2;
  return Rect.fromLTWH(dx, dy, dw, dh);
}

/// 网络图片组件 - 使用本地缩略图/预览图作为占位符
///
/// 呈现规则见 [imageDisplayRect].
/// 使用 Stack 重叠占位图与网络图, 避免切换闪烁.
class NetworkImageWidget extends StatefulWidget {
  final String imageUrl;
  final MediaAsset asset;
  final GalleryStorageService? storage;
  final int? maxDecodeEdge;
  final int rotationQuarterTurns;
  final Map<String, String> httpHeaders;
  final ValueChanged<double>? onAspectRatio;

  const NetworkImageWidget({
    super.key,
    required this.imageUrl,
    required this.asset,
    this.storage,
    this.maxDecodeEdge,
    this.rotationQuarterTurns = 0,
    this.httpHeaders = const {},
    this.onAspectRatio,
  });

  @override
  State<NetworkImageWidget> createState() => _NetworkImageWidgetState();
}

class _NetworkImageWidgetState extends State<NetworkImageWidget> {
  File? _placeholderFile;

  /// 网络原图像素尺寸
  Size? _imageSize;

  /// 本地占位图像素尺寸 (原图未就绪时按它布局, 避免尺寸跳变)
  Size? _placeholderSize;

  ImageProvider? _imageProvider;
  final _sizeListeners = <VoidCallback>{};

  final TransformationController _transformController =
      TransformationController();

  static const double _minScale = 1.0;
  static const double _maxScale = 4.0;

  /// 当前用于布局的图片尺寸
  Size? get _layoutImageSize => _imageSize ?? _placeholderSize;

  @override
  void initState() {
    super.initState();
    _loadPlaceholder();
    _updateImageProvider();
  }

  @override
  void dispose() {
    _stopMeasuring();
    _transformController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant NetworkImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id ||
        oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.maxDecodeEdge != widget.maxDecodeEdge) {
      _stopMeasuring();
      _imageSize = null;
      _placeholderSize = null;
      _placeholderFile = null;
      _transformController.value = Matrix4.identity();
      _loadPlaceholder();
      _updateImageProvider();
    }
    if (oldWidget.rotationQuarterTurns != widget.rotationQuarterTurns) {
      _transformController.value = Matrix4.identity();
    }
    if (oldWidget.asset.editParams != widget.asset.editParams &&
        _layoutImageSize != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reportAspectRatio();
      });
    }
  }

  void _reportAspectRatio() {
    final size = _layoutImageSize;
    if (size != null) widget.onAspectRatio?.call(size.width / size.height);
  }

  void _updateImageProvider() {
    final provider = CachedNetworkImageProvider(
      widget.imageUrl,
      headers: widget.httpHeaders,
    );
    _imageProvider = switch (widget.maxDecodeEdge) {
      final size? => ResizeImage(
        provider,
        width: size,
        height: size,
        policy: ResizeImagePolicy.fit,
      ),
      null => provider,
    };
    _resolveImageSize(_imageProvider!, (size) {
      if (_imageSize != size) _imageSize = size;
    });
  }

  /// 一次性读取 [provider] 的像素尺寸 (读取后立即移除监听)
  void _resolveImageSize(ImageProvider provider, void Function(Size) apply) {
    final url = widget.imageUrl;
    final stream = provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    void stop() {
      stream.removeListener(listener);
      _sizeListeners.remove(stop);
    }

    listener = ImageStreamListener((info, _) {
      stop();
      final size = Size(
        info.image.width.toDouble(),
        info.image.height.toDouble(),
      );
      info.dispose();
      if (size.width <= 0 || size.height <= 0 || !mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.imageUrl == url) {
          setState(() => apply(size));
          _reportAspectRatio();
        }
      });
    }, onError: (_, _) => stop());
    _sizeListeners.add(stop);
    stream.addListener(listener);
  }

  void _stopMeasuring() {
    for (final stop in _sizeListeners.toList()) {
      stop();
    }
  }

  Future<void> _loadPlaceholder() async {
    final storage = widget.storage;
    if (storage == null) return;
    final asset = widget.asset;

    File? file;
    try {
      file = await storage.getDisplayPreview(asset);
    } catch (e) {
      // 忽略错误, 使用加载指示器
    }

    if (!mounted || widget.asset.id != asset.id) return;
    setState(() => _placeholderFile = file);
    if (file != null) {
      _resolveImageSize(FileImage(file), (size) => _placeholderSize = size);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: RotatedBox(
        quarterTurns: widget.rotationQuarterTurns,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewport = Size(constraints.maxWidth, constraints.maxHeight);
            final painted = _paintedRect(viewport);
            return _buildInteractive(painted, viewport);
          },
        ),
      ),
    );
  }

  /// 图片在容器内的实际绘制矩形
  Rect _paintedRect(Size viewport) =>
      imageDisplayRect(viewport, _layoutImageSize);

  /// 构建可缩放的图片层
  Widget _buildInteractive(Rect painted, Size viewport) {
    final overflows = painted.height > viewport.height + 0.5;
    if (!overflows) {
      // 完整可见: 等比完整显示并居中
      return InteractiveViewer(
        transformationController: _transformController,
        minScale: _minScale,
        maxScale: _maxScale,
        constrained: true,
        child: Stack(fit: StackFit.expand, children: _imageLayers(viewport)),
      );
    }

    // 竖向超出: 以显式尺寸约束图片, 使 InteractiveViewer 允许纵向拖动查看
    return InteractiveViewer(
      transformationController: _transformController,
      minScale: _minScale,
      maxScale: _maxScale,
      constrained: false,
      child: SizedBox(
        width: painted.width,
        height: painted.height,
        child: Stack(
          fit: StackFit.expand,
          children: _imageLayers(painted.size),
        ),
      ),
    );
  }

  /// 底层占位图 + 上层网络图
  List<Widget> _imageLayers(Size viewport) {
    final provider = _imageProvider;
    final placeholder = _placeholderFile;
    final edit = ImageEdit.parse(widget.asset.editParams);
    return [
      if (placeholder != null)
        Center(child: Image.file(placeholder, fit: BoxFit.contain)),
      if (provider != null)
        Image(
          image: provider,
          fit: BoxFit.contain,
          frameBuilder: (_, child, frame, _) =>
              frame != null || placeholder != null
              ? child
              : const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
          errorBuilder: (_, _, _) => placeholder != null
              ? const SizedBox.shrink()
              : const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                    size: 48,
                  ),
                ),
        ),
      if (edit.crop != null && _imageSize != null)
        IgnorePointer(
          child: _CropPreview(
            crop: edit.cropFor(_imageSize!),
            imgSize: _imageSize!,
            painted: imageDisplayRect(viewport, _imageSize),
          ),
        ),
    ];
  }
}

/// 裁切预览 — 在 RotatedBox 内部，与图片共享坐标空间
class _CropPreview extends StatelessWidget {
  final Rect crop;
  final Size imgSize;

  /// 图片在容器内的绘制矩形
  final Rect painted;

  const _CropPreview({
    required this.crop,
    required this.painted,
    required this.imgSize,
  });

  @override
  Widget build(BuildContext context) {
    final iw = imgSize.width;
    final ih = imgSize.height;
    if (iw <= 0 || ih <= 0 || painted.width <= 0 || painted.height <= 0) {
      return const SizedBox();
    }

    final sx = painted.width / iw;
    final sy = painted.height / ih;
    final rect = Rect.fromLTRB(
      crop.left * sx + painted.left,
      crop.top * sy + painted.top,
      crop.right * sx + painted.left,
      crop.bottom * sy + painted.top,
    );

    return CustomPaint(painter: _CropPreviewPainter(rect));
  }
}

class _CropPreviewPainter extends CustomPainter {
  final Rect r;
  _CropPreviewPainter(this.r);

  @override
  void paint(Canvas c, Size s) {
    final bg = Paint()..color = Colors.black45;
    c.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & s)
        ..addRect(r),
      bg,
    );

    final bd = Paint()
      ..color = Colors.white54
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    c.drawRect(r, bd);
  }

  @override
  bool shouldRepaint(_CropPreviewPainter o) => o.r != r;
}
