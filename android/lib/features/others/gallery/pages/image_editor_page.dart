import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/providers/gallery_providers.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

/// 图片编辑器页面
/// 裁切坐标始终是“原始图片像素坐标”（不受旋转影响）
/// overlay 放在 Transform.rotate 内部，与图片共享坐标空间
class ImageEditorPage extends ConsumerStatefulWidget {
  final MediaAsset asset;
  const ImageEditorPage({super.key, required this.asset});
  @override
  ConsumerState<ImageEditorPage> createState() => _ImageEditorPageState();
}

enum _DragTarget { none, topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left, move }

class _ImageEditorPageState extends ConsumerState<ImageEditorPage> {
  int _rotation = 0;

  static const double _hs = 24.0;   // 手柄尺寸
  static const double _ew = 32.0;   // 边线热区宽度
  static const double _hPad = 24.0; // 图片水平留白（防系统手势，热区可伸入）

  /// 裁切区域 (原始图片像素坐标)
  double _cropLeft = 0, _cropTop = 0, _cropRight = 0, _cropBottom = 0;

  /// 图片原始尺寸
  Size? _imgSize;

  _DragTarget _dragTarget = _DragTarget.none;
  bool _saving = false;
  bool _cropInitialized = false;

  @override
  void initState() {
    super.initState();
    _parseExistingParams();
  }

  void _parseExistingParams() {
    final p = widget.asset.editParams;
    if (p == null) return;
    try {
      final j = jsonDecode(p) as Map<String, dynamic>;
      if (j['type'] == 'image') {
        _rotation = (j['rotation'] as int? ?? 0) % 360;
        _cropLeft = (j['crop_left'] as num?)?.toDouble() ?? 0;
        _cropTop = (j['crop_top'] as num?)?.toDouble() ?? 0;
        _cropRight = (j['crop_right'] as num?)?.toDouble() ?? 0;
        _cropBottom = (j['crop_bottom'] as num?)?.toDouble() ?? 0;
        if (_cropRight > 0 || _cropBottom > 0) _cropInitialized = true;
      }
    } catch (_) {}
  }

  void _rotate() {
    setState(() {
      _rotation = (_rotation + 90) % 360;
      // 旋转后重置为全图
      _resetToFull();
    });
  }

  void _resetToFull() {
    if (_imgSize == null) return;
    _cropLeft = 0; _cropTop = 0;
    _cropRight = _imgSize!.width; _cropBottom = _imgSize!.height;
    _cropInitialized = true;
  }

  void _onImageSizeKnown(Size sz) {
    if (_imgSize == sz) return;
    _imgSize = sz;
    if (!_cropInitialized) {
      _cropLeft = 0; _cropTop = 0;
      _cropRight = sz.width; _cropBottom = sz.height;
      _cropInitialized = true;
    }
  }

  bool get _hasCrop => _imgSize != null &&
      !(_cropLeft <= 0 && _cropTop <= 0 &&
          _cropRight >= _imgSize!.width && _cropBottom >= _imgSize!.height);

  String _buildEditParamsJson() {
    final m = <String, dynamic>{'type': 'image', 'rotation': _rotation};
    if (_hasCrop) {
      m['crop_left'] = _cropLeft.round();
      m['crop_top'] = _cropTop.round();
      m['crop_right'] = _cropRight.round();
      m['crop_bottom'] = _cropBottom.round();
    }
    return jsonEncode(m);
  }

  /// 还原至原始状态：清除 edit_params
  Future<void> _revert() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('还原至原始'),
        content: const Text('将清除所有编辑参数（旋转/裁切），恢复为原始文件状态。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final db = ref.read(galleryDatabaseProvider);
      await db.updateMediaAsset(widget.asset.copyWith(clearEditParams: true));
      await ref.read(mediaAssetListProvider.notifier).refresh();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('还原失败: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final db = ref.read(galleryDatabaseProvider);
      await db.updateMediaAsset(widget.asset.copyWith(editParams: _buildEditParamsJson()));
      await ref.read(mediaAssetListProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('编辑参数已保存'), duration: Duration(seconds: 1)),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.read(apiClientManagerProvider);
    final url = '${api.baseUrl}/API/gallery/${widget.asset.id}/file';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('图片编辑'),
        actions: [
          if (widget.asset.editParams != null)
            IconButton(icon: const Icon(Icons.undo), tooltip: '还原至原始', onPressed: _revert),
          IconButton(icon: const Icon(Icons.rotate_right), tooltip: '旋转90°', onPressed: _rotate),
          IconButton(
            icon: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check),
            tooltip: '保存', onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: LayoutBuilder(builder: (ctx, c) {
        final cw = c.maxWidth, ch = c.maxHeight;
        return InteractiveViewer(
          minScale: 0.5, maxScale: 4.0,
          child: SizedBox(
            width: cw, height: ch,
            child: Transform.rotate(
              // 负号使旋转方向为逆时针 (CCW)，与后端 imaging.Rotate90 一致
              angle: -_rotation * 3.14159 / 180,
              child: _buildImageWithOverlay(url, api.headers, cw, ch),
            ),
          ),
        );
      }),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildImageWithOverlay(String url, Map<String, String> headers, double cw, double ch) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 图片仅在水平方向留白，防系统手势；裁切热区可伸入此留白区
        Padding(
          padding: EdgeInsets.symmetric(horizontal: _hPad),
          child: CachedNetworkImage(
            imageUrl: url,
            httpHeaders: headers,
            fit: BoxFit.contain,
            width: cw - _hPad * 2,
            height: ch,
            imageBuilder: (context, provider) {
              final resolved = provider.resolve(const ImageConfiguration());
              resolved.addListener(ImageStreamListener((info, _) {
                final raw = Size(info.image.width.toDouble(), info.image.height.toDouble());
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _onImageSizeKnown(raw));
                });
              }));
              return Image(image: provider, fit: BoxFit.contain);
            },
            errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white54, size: 64),
          ),
        ),
        if (_imgSize != null) _buildCropOverlay(cw, ch),
      ],
    );
  }

  /// 计算图片以 BoxFit.contain 在容器内的实际显示矩形（考虑水平 padding）
  Rect _displayRect(double cw, double ch) {
    final iw = _imgSize!.width, ih = _imgSize!.height;
    if (iw <= 0 || ih <= 0) return Rect.zero;
    final effW = cw - _hPad * 2;
    final ia = iw / ih, ca = effW / ch;
    double dw, dh;
    if (ia > ca) { dw = effW; dh = effW / ia; }
    else { dh = ch; dw = ch * ia; }
    return Rect.fromLTWH(_hPad + (effW - dw) / 2, (ch - dh) / 2, dw, dh);
  }

  Widget _buildCropOverlay(double cw, double ch) {
    final dr = _displayRect(cw, ch);
    final sx = dr.width / _imgSize!.width;
    final sy = dr.height / _imgSize!.height;

    final cl = _cropLeft * sx + dr.left;
    final ct = _cropTop * sy + dr.top;
    final cr = _cropRight * sx + dr.left;
    final cb = _cropBottom * sy + dr.top;

    final canMoveH = (cr - cl - _hs * 2) > 0;
    final canMoveV = (cb - ct - _hs * 2) > 0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: CustomPaint(painter: _CropPainter(Rect.fromLTRB(cl, ct, cr, cb)))),
        if (canMoveH && canMoveV)
          _dragZone(cl + _hs, ct + _hs, cr - cl - _hs * 2, cb - ct - _hs * 2, _DragTarget.move),
        _dragZone(cl, ct - _ew / 2, cr - cl, _ew, _DragTarget.top),
        _dragZone(cl, cb - _ew / 2, cr - cl, _ew, _DragTarget.bottom),
        _dragZone(cl - _ew / 2, ct, _ew, cb - ct, _DragTarget.left),
        _dragZone(cr - _ew / 2, ct, _ew, cb - ct, _DragTarget.right),
        _corner(cl, ct, _DragTarget.topLeft),
        _corner(cr, ct, _DragTarget.topRight),
        _corner(cr, cb, _DragTarget.bottomRight),
        _corner(cl, cb, _DragTarget.bottomLeft),
      ],
    );
  }

  Widget _dragZone(double l, double t, double w, double h, _DragTarget tg) {
    // 防止负尺寸导致断言失败
    final safeW = w > 0 ? w : 1.0;
    final safeH = h > 0 ? h : 1.0;
    return Positioned(
      left: l, top: t, width: safeW, height: safeH,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => _dragTarget = tg,
        onPanUpdate: (d) => _onDrag(d, tg),
        onPanEnd: (_) => _dragTarget = _DragTarget.none,
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _corner(double l, double t, _DragTarget tg) {
    return Positioned(
      left: l - _hs / 2, top: t - _hs / 2,
      child: GestureDetector(
        onPanStart: (_) => _dragTarget = tg,
        onPanUpdate: (d) => _onDrag(d, tg),
        onPanEnd: (_) => _dragTarget = _DragTarget.none,
        child: Container(
          width: _hs, height: _hs,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.blue, width: 2),
            borderRadius: BorderRadius.circular(5),
          ),
        ),
      ),
    );
  }

  void _onDrag(DragUpdateDetails d, _DragTarget tg) {
    if (_imgSize == null) return;
    final iw = _imgSize!.width, ih = _imgSize!.height;
    // 用 displayRect 的 scale 反算像素移动
    final dr = _displayRect(
      (context.findRenderObject() as RenderBox?)?.size.width ?? iw,
      (context.findRenderObject() as RenderBox?)?.size.height ?? ih,
    );
    final sx = dr.width / iw;
    final sy = dr.height / ih;
    if (sx <= 0 || sy <= 0) return;
    final dx = d.delta.dx / sx;
    final dy = d.delta.dy / sy;

    setState(() {
      double cl = _cropLeft, ct = _cropTop, cr = _cropRight, cb = _cropBottom;
      switch (tg) {
        case _DragTarget.topLeft:     cl += dx; ct += dy; break;
        case _DragTarget.top:          ct += dy; break;
        case _DragTarget.topRight:    cr += dx; ct += dy; break;
        case _DragTarget.right:        cr += dx; break;
        case _DragTarget.bottomRight: cr += dx; cb += dy; break;
        case _DragTarget.bottom:       cb += dy; break;
        case _DragTarget.bottomLeft:  cl += dx; cb += dy; break;
        case _DragTarget.left:         cl += dx; break;
        case _DragTarget.move:
          final mw = cr - cl, mh = cb - ct;
          if (cl + dx >= 0 && cr + dx <= iw) { cl += dx; cr = cl + mw; }
          if (ct + dy >= 0 && cb + dy <= ih) { ct += dy; cb = ct + mh; }
          break;
        case _DragTarget.none: return;
      }
      cl = cl.clamp(0.0, cr - 50);
      ct = ct.clamp(0.0, cb - 50);
      cr = cr.clamp(cl + 50, iw);
      cb = cb.clamp(ct + 50, ih);
      _cropLeft = cl; _cropTop = ct; _cropRight = cr; _cropBottom = cb;
    });
  }

  Widget _buildBottomBar() {
    return Container(
      color: Colors.grey[900],
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('旋转: ', style: TextStyle(color: Colors.white70, fontSize: 12)),
          Text('$_rotation°', style: const TextStyle(color: Colors.white, fontSize: 12)),
          if (_imgSize != null) ...[
            const SizedBox(width: 24),
            const Text('裁切: ', style: TextStyle(color: Colors.white70, fontSize: 12)),
            Text('${_cropLeft.round()},${_cropTop.round()} → ${_cropRight.round()}×${_cropBottom.round()}',
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
          const SizedBox(width: 24),
          TextButton(
            onPressed: _imgSize != null ? () => setState(_resetToFull) : null,
            child: const Text('重置裁切', style: TextStyle(color: Colors.white54, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

/// 裁切遮罩绘制器
class _CropPainter extends CustomPainter {
  final Rect r;
  _CropPainter(this.r);
  @override
  void paint(Canvas c, Size s) {
    final bg = Paint()..color = Colors.black54;
    c.drawRect(Rect.fromLTWH(0, 0, s.width, r.top), bg);
    c.drawRect(Rect.fromLTWH(0, r.bottom, s.width, s.height - r.bottom), bg);
    c.drawRect(Rect.fromLTWH(0, r.top, r.left, r.height), bg);
    c.drawRect(Rect.fromLTWH(r.right, r.top, s.width - r.right, r.height), bg);
    final bd = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2;
    c.drawRect(r, bd);
    final ds = Paint()..color = Colors.white24..style = PaintingStyle.stroke..strokeWidth = 0.5;
    for (int i = 1; i < 3; i++) {
      final x = r.left + r.width / 3 * i;
      c.drawLine(Offset(x, r.top), Offset(x, r.bottom), ds);
      final y = r.top + r.height / 3 * i;
      c.drawLine(Offset(r.left, y), Offset(r.right, y), ds);
    }
  }
  @override
  bool shouldRepaint(_CropPainter o) => o.r != r;
}
