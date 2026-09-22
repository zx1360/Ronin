import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/services/gallery_storage_service.dart';

/// 计算图片在容器内的绘制矩形
///
/// - 竖屏容器(宽 < 高): 先按宽度对齐容器; 高度超出则从图片顶部开始显示
///   (由调用方提供纵向拖动), 未超出则垂直居中;
/// - 横屏容器(含应用内旋转 90° 后的显示区域): 保持等比完整显示并居中.
///
/// 图片尺寸未知时退化为铺满容器(与改动前的等比显示等价).
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

  /// 网络原图像素尺寸
  Size? _imageSize;

  /// 本地占位图像素尺寸 (原图未就绪时按它布局, 避免尺寸跳变)
  Size? _placeholderSize;

  CachedNetworkImageProvider? _imageProvider;

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
    _transformController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant NetworkImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id ||
        oldWidget.imageUrl != widget.imageUrl) {
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
  }

  void _updateImageProvider() {
    _imageProvider =
        CachedNetworkImageProvider(widget.imageUrl, headers: widget.httpHeaders);
    _resolveImageSize(_imageProvider!, (size) {
      if (_imageSize != size) _imageSize = size;
    });
  }

  /// 一次性读取 [provider] 的像素尺寸 (读取后立即移除监听)
  void _resolveImageSize(ImageProvider provider, void Function(Size) apply) {
    final stream = provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        stream.removeListener(listener);
        final size = Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        );
        if (size.width <= 0 || size.height <= 0 || !mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => apply(size));
        });
      },
      onError: (_, __) => stream.removeListener(listener),
    );
    stream.addListener(listener);
  }

  Future<void> _loadPlaceholder() async {
    setState(() => _isLoading = true);

    File? file;
    try {
      if (widget.asset.previewPath != null) {
        file = await widget.storage.getPreviewFile(widget.asset.previewPath!);
      }
      if (file == null && widget.asset.thumbPath != null) {
        file = await widget.storage.getThumbFile(widget.asset.thumbPath!);
      }
    } catch (e) {
      // 忽略错误, 使用加载指示器
    }

    if (!mounted) return;
    setState(() {
      _placeholderFile = file;
      _isLoading = false;
    });
    if (file != null) {
      _resolveImageSize(FileImage(file), (size) => _placeholderSize = size);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crop = _parseCrop();
    return Container(
      color: Colors.black,
      child: RotatedBox(
        quarterTurns: widget.rotationQuarterTurns,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewport =
                Size(constraints.maxWidth, constraints.maxHeight);
            final painted = _paintedRect(viewport);
            return Stack(
              fit: StackFit.expand,
              children: [
                _buildInteractive(painted, viewport),
                if (crop != null)
                  IgnorePointer(
                    child: _CropPreview(
                      crop: crop,
                      imgSize: _layoutImageSize,
                      painted: painted,
                    ),
                  ),
              ],
            );
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
      // 完整可见: 与改动前一致的等比显示 (居中)
      return InteractiveViewer(
        transformationController: _transformController,
        minScale: _minScale,
        maxScale: _maxScale,
        constrained: true,
        child: Stack(fit: StackFit.expand, children: _imageLayers()),
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
        child: Stack(fit: StackFit.expand, children: _imageLayers()),
      ),
    );
  }

  /// 底层占位图 + 上层网络图
  List<Widget> _imageLayers() {
    final provider = _imageProvider;
    return [
      _buildPlaceholderLayer(),
      if (provider != null)
        Image(
          image: provider,
          fit: BoxFit.contain,
          errorBuilder: (ctx, error, stackTrace) {
            // 网络图加载失败时保留底层占位图
            return const SizedBox.shrink();
          },
        ),
    ];
  }

  /// 占位图层：根据状态显示加载指示器、缩略图或空白
  Widget _buildPlaceholderLayer() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_placeholderFile != null) {
      return Center(
        child: Image.file(_placeholderFile!, fit: BoxFit.contain),
      );
    }

    // 无缩略图可用时显示加载指示器（网络图可能很快加载）
    return const Center(
      child: CircularProgressIndicator(color: Colors.white),
    );
  }

  _CropRect? _parseCrop() {
    final p = widget.asset.editParams;
    if (p == null) return null;
    try {
      final j = jsonDecode(p) as Map<String, dynamic>;
      if (j['type'] != 'image') return null;
      final cl = (j['crop_left'] as num?)?.toDouble();
      final ct = (j['crop_top'] as num?)?.toDouble();
      final cr = (j['crop_right'] as num?)?.toDouble();
      final cb = (j['crop_bottom'] as num?)?.toDouble();
      if (cl == null || ct == null || cr == null || cb == null) return null;
      if (cl <= 0 && ct <= 0 && cr <= 0 && cb <= 0) return null;
      return _CropRect(left: cl, top: ct, right: cr, bottom: cb);
    } catch (_) {}
    return null;
  }
}

/// 裁切数据 (原始图片像素坐标)
class _CropRect {
  final double left, top, right, bottom;
  const _CropRect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });
}

/// 裁切预览 — 在 RotatedBox 内部，与图片共享坐标空间
class _CropPreview extends StatelessWidget {
  final _CropRect crop;
  final Size? imgSize;

  /// 图片在容器内的绘制矩形
  final Rect painted;

  const _CropPreview({
    required this.crop,
    required this.painted,
    this.imgSize,
  });

  @override
  Widget build(BuildContext context) {
    final iw = imgSize?.width ?? crop.right;
    final ih = imgSize?.height ?? crop.bottom;
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
    c.drawRect(Rect.fromLTWH(0, 0, s.width, r.top), bg);
    c.drawRect(Rect.fromLTWH(0, r.bottom, s.width, s.height - r.bottom), bg);
    c.drawRect(Rect.fromLTWH(0, r.top, r.left, r.height), bg);
    c.drawRect(Rect.fromLTWH(r.right, r.top, s.width - r.right, r.height), bg);

    final bd = Paint()
      ..color = Colors.white54
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    c.drawRect(r, bd);
  }

  @override
  bool shouldRepaint(_CropPreviewPainter o) => o.r != r;
}
