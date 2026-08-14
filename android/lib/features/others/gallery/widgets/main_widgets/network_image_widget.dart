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
  Size? _imageSize; // 图片实际像素尺寸 (从 imageBuilder 捕获)

  final TransformationController _transformController =
      TransformationController();

  // 新增：管理 ImageStream 监听器
  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;

  static const double _minScale = 1.0;
  static const double _maxScale = 4.0;

  @override
  void initState() {
    super.initState();
    _loadPlaceholder();
  }

  @override
  void dispose() {
    _removeImageStreamListener(); // 新增：释放监听器
    _transformController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant NetworkImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id) {
      _loadPlaceholder();
      _transformController.value = Matrix4.identity();
    }
    if (oldWidget.rotationQuarterTurns != widget.rotationQuarterTurns) {
      _transformController.value = Matrix4.identity();
    }
  }

  /// 新增：安全移除 ImageStream 监听器
  void _removeImageStreamListener() {
    if (_imageStream != null && _imageStreamListener != null) {
      _imageStream!.removeListener(_imageStreamListener!);
      _imageStream = null;
      _imageStreamListener = null;
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
    final crop = _parseCrop();
    return Container(
      color: Colors.black,
      child: RotatedBox(
        quarterTurns: widget.rotationQuarterTurns,
        child: crop != null
            ? LayoutBuilder(
                builder: (ctx, c) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: widget.imageUrl,
                        httpHeaders: widget.httpHeaders,
                        imageBuilder: (_, p) {
                          _captureImageSize(p);
                          return _buildInteractiveImage(
                            p,
                            ValueKey(
                              'img_${widget.asset.id}_${widget.rotationQuarterTurns}',
                            ),
                          );
                        },
                        placeholder: (_, __) => _buildPlaceholderOrLoading(),
                        errorWidget: (_, __, ___) => _buildErrorOrPlaceholder(),
                      ),
                      IgnorePointer(
                        child: _CropPreview(crop: crop, imgSize: _imageSize),
                      ),
                    ],
                  );
                },
              )
            : CachedNetworkImage(
                imageUrl: widget.imageUrl,
                httpHeaders: widget.httpHeaders,
                imageBuilder: (_, p) {
                  _captureImageSize(p);
                  return _buildInteractiveImage(
                    p,
                    ValueKey(
                      'img_${widget.asset.id}_${widget.rotationQuarterTurns}',
                    ),
                  );
                },
                placeholder: (_, __) => _buildPlaceholderOrLoading(),
                errorWidget: (_, __, ___) => _buildErrorOrPlaceholder(),
              ),
      ),
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

  /// 从 imageProvider 捕获实际图片像素尺寸。
  /// 修复：每次添加新监听器前移除旧监听器，避免累积。
  void _captureImageSize(ImageProvider p) {
    _removeImageStreamListener(); // 移除旧监听器

    final stream = p.resolve(const ImageConfiguration());
    final listener = ImageStreamListener((info, _) {
      final sz = Size(
        info.image.width.toDouble(),
        info.image.height.toDouble(),
      );
      if (_imageSize != sz && sz.width > 0 && sz.height > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _imageSize = sz);
        });
      }
    });

    stream.addListener(listener);
    _imageStream = stream;
    _imageStreamListener = listener;
  }

  Widget _buildInteractiveImage(ImageProvider imageProvider, Key key) {
    return LayoutBuilder(
      builder: ((context, constraints) {
        final width = constraints.maxWidth;
        return InteractiveViewer(
          key: key,
          transformationController: _transformController,
          minScale: _minScale,
          maxScale: _maxScale,
          constrained: true,
          child: Image(
            image: imageProvider,
            fit: BoxFit.contain,
            width: width,
          ),
        );
      }),
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
          'placeholder_${widget.asset.id}_${widget.rotationQuarterTurns}',
        ),
        minScale: _minScale,
        maxScale: _maxScale,
        constrained: true,
        child: Center(
          child: Image.file(_placeholderFile!, fit: BoxFit.contain),
        ),
      );
    }

    return const Center(child: CircularProgressIndicator(color: Colors.white));
  }

  Widget _buildErrorOrPlaceholder() {
    if (_placeholderFile != null) {
      return InteractiveViewer(
        key: ValueKey(
          'error_${widget.asset.id}_${widget.rotationQuarterTurns}',
        ),
        minScale: _minScale,
        maxScale: _maxScale,
        constrained: true,
        child: Center(
          child: Image.file(_placeholderFile!, fit: BoxFit.contain),
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error, color: Colors.red, size: 48),
          const SizedBox(height: 8),
          Text('加载失败', style: TextStyle(color: Colors.grey[400])),
        ],
      ),
    );
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

/// 裁切预览 — 在 RotatedBox 内部，与图片共享坐标空间 TODO: 缩放拖拽后裁切预览框位置不变的解决.
class _CropPreview extends StatelessWidget {
  final _CropRect crop;
  final Size? imgSize; // 可选：已知的图片像素尺寸
  const _CropPreview({required this.crop, this.imgSize});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, c) {
        final cw = c.maxWidth, ch = c.maxHeight;
        if (cw <= 0 || ch <= 0) return const SizedBox();

        // 用 crop 的 [right, bottom] 估算图片尺寸；如果 imgSize 已知则用 imgSize
        final iw = imgSize?.width ?? crop.right;
        final ih = imgSize?.height ?? crop.bottom;
        if (iw <= 0 || ih <= 0) return const SizedBox();

        // 与编辑器一致的 display rect 计算
        final ia = iw / ih, ca = cw / ch;
        double dw, dh;
        if (ia > ca) {
          dw = cw;
          dh = cw / ia;
        } else {
          dh = ch;
          dw = ch * ia;
        }
        final ox = (cw - dw) / 2, oy = (ch - dh) / 2;
        final sx = dw / iw, sy = dh / ih;

        final cl = crop.left * sx + ox;
        final ct = crop.top * sy + oy;
        final cr = crop.right * sx + ox;
        final cb = crop.bottom * sy + oy;

        return CustomPaint(
          painter: _CropPreviewPainter(Rect.fromLTRB(cl, ct, cr, cb)),
        );
      },
    );
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