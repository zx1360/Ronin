import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/providers/gallery_providers.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

/// 图片编辑器页面
/// 支持旋转（90°步进）和裁切（四边+四角拖拽 + 中间移动）
class ImageEditorPage extends ConsumerStatefulWidget {
  final MediaAsset asset;

  const ImageEditorPage({super.key, required this.asset});

  @override
  ConsumerState<ImageEditorPage> createState() => _ImageEditorPageState();
}

enum _DragTarget { none, topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left, move }

class _ImageEditorPageState extends ConsumerState<ImageEditorPage> {
  int _rotation = 0;

  /// 裁切区域 (相对于旋转后图像的像素坐标)
  double _cropLeft = 0;
  double _cropTop = 0;
  double _cropRight = 0;
  double _cropBottom = 0;

  /// 图片原始尺寸 (旋转后)
  Size? _imageSize;

  final GlobalKey _imageKey = GlobalKey();

  _DragTarget _dragTarget = _DragTarget.none;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _parseExistingParams();
  }

  void _parseExistingParams() {
    final params = widget.asset.editParams;
    if (params == null) return;
    try {
      final json = jsonDecode(params) as Map<String, dynamic>;
      if (json['type'] == 'image') {
        _rotation = (json['rotation'] as int? ?? 0) % 360;
        _cropLeft = (json['crop_left'] as num?)?.toDouble() ?? 0;
        _cropTop = (json['crop_top'] as num?)?.toDouble() ?? 0;
        _cropRight = (json['crop_right'] as num?)?.toDouble() ?? 0;
        _cropBottom = (json['crop_bottom'] as num?)?.toDouble() ?? 0;
      }
    } catch (_) {}
  }

  void _rotate() {
    setState(() {
      _rotation = (_rotation + 90) % 360;
      if (_imageSize != null) {
        _cropLeft = 0;
        _cropTop = 0;
        _cropRight = _imageSize!.width;
        _cropBottom = _imageSize!.height;
      }
    });
  }

  String _buildEditParamsJson() {
    final map = <String, dynamic>{'type': 'image', 'rotation': _rotation};
    if (_imageSize != null && _hasCrop) {
      map['crop_left'] = _cropLeft.round();
      map['crop_top'] = _cropTop.round();
      map['crop_right'] = _cropRight.round();
      map['crop_bottom'] = _cropBottom.round();
    }
    return jsonEncode(map);
  }

  bool get _hasCrop =>
      _imageSize != null &&
      !(_cropLeft <= 0 && _cropTop <= 0 &&
          _cropRight >= _imageSize!.width && _cropBottom >= _imageSize!.height);

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final db = ref.read(galleryDatabaseProvider);
      final updatedAsset = widget.asset.copyWith(editParams: _buildEditParamsJson());
      await db.updateMediaAsset(updatedAsset);
      await ref.read(mediaAssetListProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('编辑参数已保存，同步后将应用'), duration: Duration(seconds: 2)),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final apiClient = ref.read(apiClientManagerProvider);
    final baseUrl = apiClient.baseUrl;
    final headers = apiClient.headers;
    final imageUrl = '$baseUrl/API/gallery/${widget.asset.id}/file';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('图片编辑'),
        actions: [
          IconButton(icon: const Icon(Icons.rotate_right), tooltip: '旋转 90°', onPressed: _rotate),
          IconButton(
            icon: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check),
            tooltip: '保存',
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 3.0,
                child: SizedBox(
                  key: _imageKey,
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Transform.rotate(
                        angle: _rotation * 3.14159 / 180,
                        child: Center(
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            httpHeaders: headers,
                            fit: BoxFit.contain,
                            width: constraints.maxWidth,
                            height: constraints.maxHeight,
                            imageBuilder: (context, imageProvider) {
                              final resolved = imageProvider.resolve(const ImageConfiguration());
                              resolved.addListener(ImageStreamListener((info, _) {
                                final rawSize = Size(info.image.width.toDouble(), info.image.height.toDouble());
                                final rotatedSize = _rotation % 180 == 0 ? rawSize : Size(rawSize.height, rawSize.width);
                                if (_imageSize != rotatedSize) {
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (mounted) {
                                      setState(() {
                                        _imageSize = rotatedSize;
                                        _initCropToFull();
                                      });
                                    }
                                  });
                                }
                              }));
                              return Image(image: imageProvider, fit: BoxFit.contain);
                            },
                            errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white54, size: 64),
                          ),
                        ),
                      ),
                      if (_imageSize != null) _buildCropOverlay(constraints),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: Container(
        color: Colors.grey[900],
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('旋转: ', style: TextStyle(color: Colors.white70, fontSize: 12)),
            Text('$_rotation°', style: const TextStyle(color: Colors.white, fontSize: 12)),
            if (_imageSize != null) ...[
              const SizedBox(width: 24),
              const Text('裁切: ', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text('${_cropLeft.round()},${_cropTop.round()} → ${_cropRight.round()}×${_cropBottom.round()}',
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            ],
            const SizedBox(width: 24),
            TextButton(
              onPressed: _imageSize != null ? _resetCrop : null,
              child: const Text('重置裁切', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  void _initCropToFull() {
    if (_imageSize == null) return;
    if (_cropRight <= 0 || _cropBottom <= 0) {
      _cropLeft = 0;
      _cropTop = 0;
      _cropRight = _imageSize!.width;
      _cropBottom = _imageSize!.height;
    }
  }

  void _resetCrop() {
    if (_imageSize == null) return;
    setState(() {
      _cropLeft = 0;
      _cropTop = 0;
      _cropRight = _imageSize!.width;
      _cropBottom = _imageSize!.height;
    });
  }

  /// 计算图片在容器中的实际显示区域
  Rect _computeImageDisplayRect(BoxConstraints constraints) {
    final imgW = _imageSize!.width;
    final imgH = _imageSize!.height;
    final cw = constraints.maxWidth;
    final ch = constraints.maxHeight;
    final imgAspect = imgW / imgH;
    final containerAspect = cw / ch;

    double dw, dh;
    if (imgAspect > containerAspect) { dw = cw; dh = cw / imgAspect; }
    else { dh = ch; dw = ch * imgAspect; }

    final ox = (cw - dw) / 2;
    final oy = (ch - dh) / 2;
    return Rect.fromLTWH(ox, oy, dw, dh);
  }

  Widget _buildCropOverlay(BoxConstraints constraints) {
    if (_imageSize == null) return const SizedBox();
    final imgW = _imageSize!.width;
    final imgH = _imageSize!.height;

    final displayRect = _computeImageDisplayRect(constraints);
    final scaleX = displayRect.width / imgW;
    final scaleY = displayRect.height / imgH;

    final cl = _cropLeft * scaleX + displayRect.left;
    final ct = _cropTop * scaleY + displayRect.top;
    final cr = _cropRight * scaleX + displayRect.left;
    final cb = _cropBottom * scaleY + displayRect.top;

    const handleSize = 20.0;
    const edgeWidth = 20.0; // 边线拖拽热区

    // 整个裁切框区域用于移动
    Widget moveArea() => Positioned(
      left: cl + handleSize, top: ct + handleSize,
      width: cr - cl - handleSize * 2, height: cb - ct - handleSize * 2,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => _dragTarget = _DragTarget.move,
        onPanUpdate: (d) => _onEdgeDrag(d, _DragTarget.move, scaleX, scaleY, imgW, imgH, displayRect),
        onPanEnd: (_) => _dragTarget = _DragTarget.none,
        child: Container(color: Colors.transparent),
      ),
    );

    // 边线拖拽热区
    Widget edge(double l, double t, double w, double h, _DragTarget target) => Positioned(
      left: l, top: t, width: w, height: h,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => _dragTarget = target,
        onPanUpdate: (d) => _onEdgeDrag(d, target, scaleX, scaleY, imgW, imgH, displayRect),
        onPanEnd: (_) => _dragTarget = _DragTarget.none,
        child: Container(color: Colors.transparent),
      ),
    );

    // 角手柄
    Widget corner(double l, double t, _DragTarget target) => Positioned(
      left: l - handleSize / 2, top: t - handleSize / 2,
      child: GestureDetector(
        onPanStart: (_) => _dragTarget = target,
        onPanUpdate: (d) => _onEdgeDrag(d, target, scaleX, scaleY, imgW, imgH, displayRect),
        onPanEnd: (_) => _dragTarget = _DragTarget.none,
        child: Container(
          width: handleSize, height: handleSize,
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.blue, width: 2), borderRadius: BorderRadius.circular(4)),
        ),
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: CustomPaint(painter: _CropMaskPainter(cropRect: Rect.fromLTRB(cl, ct, cr, cb)))),
        // 移动区域
        moveArea(),
        // 四边热区（角部被角手柄的 GestureDetector 优先捕获）
        edge(cl + handleSize, ct - edgeWidth / 2, cr - cl - handleSize * 2, edgeWidth, _DragTarget.top),
        edge(cl + handleSize, cb - edgeWidth / 2, cr - cl - handleSize * 2, edgeWidth, _DragTarget.bottom),
        edge(cl - edgeWidth / 2, ct + handleSize, edgeWidth, cb - ct - handleSize * 2, _DragTarget.left),
        edge(cr - edgeWidth / 2, ct + handleSize, edgeWidth, cb - ct - handleSize * 2, _DragTarget.right),
        // 四角
        corner(cl, ct, _DragTarget.topLeft),
        corner(cr, ct, _DragTarget.topRight),
        corner(cr, cb, _DragTarget.bottomRight),
        corner(cl, cb, _DragTarget.bottomLeft),
      ],
    );
  }

  void _onEdgeDrag(DragUpdateDetails d, _DragTarget target, double scaleX, double scaleY,
      double imgW, double imgH, Rect displayRect) {
    final dx = d.delta.dx / scaleX;
    final dy = d.delta.dy / scaleY;

    setState(() {
      double cl = _cropLeft, ct = _cropTop, cr = _cropRight, cb = _cropBottom;
      switch (target) {
        case _DragTarget.topLeft:    cl += dx; ct += dy; break;
        case _DragTarget.top:        ct += dy; break;
        case _DragTarget.topRight:   cr += dx; ct += dy; break;
        case _DragTarget.right:      cr += dx; break;
        case _DragTarget.bottomRight:cr += dx; cb += dy; break;
        case _DragTarget.bottom:     cb += dy; break;
        case _DragTarget.bottomLeft: cl += dx; cb += dy; break;
        case _DragTarget.left:       cl += dx; break;
        case _DragTarget.move:
          final md = cr - cl; final mh = cb - cl;
          if (cl + dx >= 0 && cr + dx <= imgW) { cl += dx; cr = cl + md; }
          if (ct + dy >= 0 && cb + dy <= imgH) { ct += dy; cb = ct + mh; }
          break;
        case _DragTarget.none: return;
      }
      cl = cl.clamp(0.0, cr - 50);
      ct = ct.clamp(0.0, cb - 50);
      cr = cr.clamp(cl + 50, imgW);
      cb = cb.clamp(ct + 50, imgH);
      _cropLeft = cl; _cropTop = ct; _cropRight = cr; _cropBottom = cb;
    });
  }
}

/// 裁切遮罩绘制器
class _CropMaskPainter extends CustomPainter {
  final Rect cropRect;
  _CropMaskPainter({required this.cropRect});

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = Colors.black54;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, cropRect.top), bg);
    canvas.drawRect(Rect.fromLTWH(0, cropRect.bottom, size.width, size.height - cropRect.bottom), bg);
    canvas.drawRect(Rect.fromLTWH(0, cropRect.top, cropRect.left, cropRect.height), bg);
    canvas.drawRect(Rect.fromLTWH(cropRect.right, cropRect.top, size.width - cropRect.right, cropRect.height), bg);

    final border = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2;
    canvas.drawRect(cropRect, border);

    final dash = Paint()..color = Colors.white30..style = PaintingStyle.stroke..strokeWidth = 0.5;
    for (int i = 1; i < 3; i++) {
      final x = cropRect.left + cropRect.width / 3 * i;
      canvas.drawLine(Offset(x, cropRect.top), Offset(x, cropRect.bottom), dash);
      final y = cropRect.top + cropRect.height / 3 * i;
      canvas.drawLine(Offset(cropRect.left, y), Offset(cropRect.right, y), dash);
    }
  }

  @override
  bool shouldRepaint(covariant _CropMaskPainter o) => o.cropRect != cropRect;
}
