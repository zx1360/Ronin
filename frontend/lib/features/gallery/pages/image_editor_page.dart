import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/core/api/generated/api_contract.dart' show ApiPath;
import 'package:torrid/features/gallery/models/media_asset.dart';
import 'package:torrid/features/gallery/providers/gallery_providers.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

/// 图片编辑器页面
/// 裁切坐标始终是“原始图片像素坐标”（不受旋转影响）
/// overlay 放在 Transform.rotate 内部，与图片共享坐标空间
///
/// 旋转/裁切数值与保存由 [ImageEdit] 持有, 页面只保留手势与布局。
class ImageEditorPage extends ConsumerStatefulWidget {
  final MediaAsset asset;
  const ImageEditorPage({super.key, required this.asset});
  @override
  ConsumerState<ImageEditorPage> createState() => _ImageEditorPageState();
}

class _ImageEditorPageState extends ConsumerState<ImageEditorPage> {
  static const double _hs = 24.0;   // 手柄尺寸
  static const double _ew = 32.0;   // 边线热区宽度
  static const double _hPad = 24.0; // 图片水平留白（防系统手势，热区可伸入）

  @override
  void initState() {
    super.initState();
    ref.read(imageEditProvider.notifier).load(widget.asset);
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
      await ref.read(imageEditProvider.notifier).revert();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('还原失败: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _save() async {
    try {
      await ref.read(imageEditProvider.notifier).save();
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.read(apiClientManagerProvider);
    final url = '${api.baseUrl}${ApiPath.galleryIdTypePath(widget.asset.id, 'file')}';
    final edit = ref.watch(imageEditProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('图片编辑'),
        actions: [
          if (widget.asset.editParams != null)
            IconButton(icon: const Icon(Icons.undo), tooltip: '还原至原始', onPressed: _revert),
          IconButton(
            icon: const Icon(Icons.rotate_right),
            tooltip: '旋转90°',
            onPressed: () => ref.read(imageEditProvider.notifier).rotate(),
          ),
          IconButton(
            icon: edit.saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check),
            tooltip: '保存', onPressed: edit.saving ? null : _save,
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
              angle: -edit.rotation * 3.14159 / 180,
              child: _buildImageWithOverlay(url, api.headers, cw, ch, edit),
            ),
          ),
        );
      }),
      bottomNavigationBar: _buildBottomBar(edit),
    );
  }

  Widget _buildImageWithOverlay(String url, Map<String, String> headers, double cw, double ch, ImageEditState edit) {
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
                  if (mounted) {
                    ref.read(imageEditProvider.notifier).setImageSize(raw);
                  }
                });
              }));
              return Image(image: provider, fit: BoxFit.contain);
            },
            errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white54, size: 64),
          ),
        ),
        if (edit.imageSize != null) _buildCropOverlay(cw, ch, edit),
      ],
    );
  }

  /// 计算图片以 BoxFit.contain 在容器内的实际显示矩形（考虑水平 padding）
  Rect _displayRect(double cw, double ch, Size imgSize) {
    final iw = imgSize.width, ih = imgSize.height;
    if (iw <= 0 || ih <= 0) return Rect.zero;
    final effW = cw - _hPad * 2;
    final ia = iw / ih, ca = effW / ch;
    double dw, dh;
    if (ia > ca) { dw = effW; dh = effW / ia; }
    else { dh = ch; dw = ch * ia; }
    return Rect.fromLTWH(_hPad + (effW - dw) / 2, (ch - dh) / 2, dw, dh);
  }

  Widget _buildCropOverlay(double cw, double ch, ImageEditState edit) {
    final imgSize = edit.imageSize!;
    final dr = _displayRect(cw, ch, imgSize);
    final sx = dr.width / imgSize.width;
    final sy = dr.height / imgSize.height;

    final cl = edit.cropLeft * sx + dr.left;
    final ct = edit.cropTop * sy + dr.top;
    final cr = edit.cropRight * sx + dr.left;
    final cb = edit.cropBottom * sy + dr.top;

    final canMoveH = (cr - cl - _hs * 2) > 0;
    final canMoveV = (cb - ct - _hs * 2) > 0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: CustomPaint(painter: _CropPainter(Rect.fromLTRB(cl, ct, cr, cb)))),
        if (canMoveH && canMoveV)
          _dragZone(cl + _hs, ct + _hs, cr - cl - _hs * 2, cb - ct - _hs * 2, ImageCropHandle.move),
        _dragZone(cl, ct - _ew / 2, cr - cl, _ew, ImageCropHandle.top),
        _dragZone(cl, cb - _ew / 2, cr - cl, _ew, ImageCropHandle.bottom),
        _dragZone(cl - _ew / 2, ct, _ew, cb - ct, ImageCropHandle.left),
        _dragZone(cr - _ew / 2, ct, _ew, cb - ct, ImageCropHandle.right),
        _corner(cl, ct, ImageCropHandle.topLeft),
        _corner(cr, ct, ImageCropHandle.topRight),
        _corner(cr, cb, ImageCropHandle.bottomRight),
        _corner(cl, cb, ImageCropHandle.bottomLeft),
      ],
    );
  }

  Widget _dragZone(double l, double t, double w, double h, ImageCropHandle tg) {
    // 防止负尺寸导致断言失败
    final safeW = w > 0 ? w : 1.0;
    final safeH = h > 0 ? h : 1.0;
    return Positioned(
      left: l, top: t, width: safeW, height: safeH,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) {},
        onPanUpdate: (d) => _onDrag(d, tg),
        onPanEnd: (_) {},
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _corner(double l, double t, ImageCropHandle tg) {
    return Positioned(
      left: l - _hs / 2, top: t - _hs / 2,
      child: GestureDetector(
        onPanStart: (_) {},
        onPanUpdate: (d) => _onDrag(d, tg),
        onPanEnd: (_) {},
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

  /// 屏幕位移换算为原图像素位移后交给 [ImageEdit]
  void _onDrag(DragUpdateDetails d, ImageCropHandle tg) {
    final imgSize = ref.read(imageEditProvider).imageSize;
    if (imgSize == null) return;
    final iw = imgSize.width, ih = imgSize.height;
    // 用 displayRect 的 scale 反算像素移动
    final dr = _displayRect(
      (context.findRenderObject() as RenderBox?)?.size.width ?? iw,
      (context.findRenderObject() as RenderBox?)?.size.height ?? ih,
      imgSize,
    );
    final sx = dr.width / iw;
    final sy = dr.height / ih;
    if (sx <= 0 || sy <= 0) return;
    ref.read(imageEditProvider.notifier).drag(tg, d.delta.dx / sx, d.delta.dy / sy);
  }

  Widget _buildBottomBar(ImageEditState edit) {
    return Container(
      color: Colors.grey[900],
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('旋转: ', style: TextStyle(color: Colors.white70, fontSize: 12)),
          Text('${edit.rotation}°', style: const TextStyle(color: Colors.white, fontSize: 12)),
          if (edit.imageSize != null) ...[
            const SizedBox(width: 24),
            const Text('裁切: ', style: TextStyle(color: Colors.white70, fontSize: 12)),
            Text('${edit.cropLeft.round()},${edit.cropTop.round()} → ${edit.cropRight.round()}×${edit.cropBottom.round()}',
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
          const SizedBox(width: 24),
          TextButton(
            onPressed: edit.imageSize != null
                ? () => ref.read(imageEditProvider.notifier).resetCropToFull()
                : null,
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
