import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/gallery/models/image_edit.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/providers/gallery_providers.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

class ImageEditorPage extends ConsumerStatefulWidget {
  final MediaAsset asset;
  const ImageEditorPage({super.key, required this.asset});

  @override
  ConsumerState<ImageEditorPage> createState() => _ImageEditorPageState();
}

enum _DragTarget {
  topLeft,
  top,
  topRight,
  right,
  bottomRight,
  bottom,
  bottomLeft,
  left,
  move,
}

class _ImageEditorPageState extends ConsumerState<ImageEditorPage> {
  final _canvasKey = GlobalKey();
  final _transform = TransformationController();
  late ImageEdit _edit;
  late ImageProvider _provider;
  ImageStream? _stream;
  ImageStreamListener? _listener;
  Size? _imageSize;
  Offset? _dragStart;
  Rect? _dragCrop;
  bool _saving = false;
  bool _panMode = false;
  bool _imageFailed = false;

  @override
  void initState() {
    super.initState();
    _edit = ImageEdit.parse(widget.asset.editParams);
    final api = ref.read(apiClientManagerProvider);
    _provider = CachedNetworkImageProvider(
      galleryMediaUrl(api.baseUrl, widget.asset),
      headers: api.headers,
    );
    _resolveImage();
  }

  void _resolveImage() {
    _removeListener();
    _stream = _provider.resolve(ImageConfiguration.empty);
    _listener = ImageStreamListener(
      (info, _) {
        final size = Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        );
        _removeListener();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _imageSize = size;
              _imageFailed = false;
            });
          }
        });
      },
      onError: (_, __) {
        _removeListener();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _imageFailed = true);
        });
      },
    );
    _stream!.addListener(_listener!);
  }

  void _removeListener() {
    if (_listener != null) _stream?.removeListener(_listener!);
    _listener = null;
    _stream = null;
  }

  @override
  void dispose() {
    _removeListener();
    _transform.dispose();
    super.dispose();
  }

  Future<void> _save({bool restore = false}) async {
    if (_saving || (!restore && _imageSize == null)) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(mediaAssetListProvider.notifier)
          .setEditParams(
            widget.asset,
            restore ? null : _edit.encode(_imageSize!),
          );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('编辑已保存，原文件将在后端执行编辑时更新')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _restore() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除待执行的编辑'),
        content: const Text('清除旋转和裁切参数；已由后端执行的编辑不会撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) await _save(restore: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('图片裁切'),
        actions: [
          if (widget.asset.editParams != null)
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: '清除待执行的编辑',
              onPressed: _saving ? null : _restore,
            ),
          IconButton(
            icon: const Icon(Icons.rotate_left),
            tooltip: '逆时针旋转90°',
            onPressed: _saving || _imageSize == null
                ? null
                : () => setState(() {
                    _edit = ImageEdit(
                      rotation: (_edit.rotation + 90) % 360,
                      crop: _edit.crop,
                    );
                    _transform.value = Matrix4.identity();
                  }),
          ),
          IconButton(
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            tooltip: '保存',
            onPressed: _saving || _imageSize == null ? null : () => _save(),
          ),
        ],
      ),
      body: _imageFailed
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '原图加载失败，请检查连接',
                    style: TextStyle(color: Colors.white70),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => _imageFailed = false);
                      _resolveImage();
                    },
                    child: const Text('重试'),
                  ),
                ],
              ),
            )
          : _imageSize == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: InteractiveViewer(
                transformationController: _transform,
                panEnabled: _panMode,
                scaleEnabled: _panMode,
                minScale: 1,
                maxScale: 6,
                child: RotatedBox(
                  quarterTurns: _edit.quarterTurns,
                  child: LayoutBuilder(
                    builder: (_, constraints) {
                      final viewport = constraints.biggest;
                      final fit = applyBoxFit(
                        BoxFit.contain,
                        _imageSize!,
                        viewport,
                      ).destination;
                      final painted = Alignment.center.inscribe(
                        fit,
                        Offset.zero & viewport,
                      );
                      return SizedBox(
                        key: _canvasKey,
                        width: viewport.width,
                        height: viewport.height,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fromRect(
                              rect: painted,
                              child: Image(image: _provider, fit: BoxFit.fill),
                            ),
                            ..._cropOverlay(painted),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            children: [
              Text(
                _cropDescription,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              TextButton.icon(
                onPressed: _imageSize == null || _saving
                    ? null
                    : () => setState(() => _panMode = !_panMode),
                icon: Icon(_panMode ? Icons.crop : Icons.zoom_in),
                label: Text(_panMode ? '返回裁切' : '缩放查看'),
              ),
              TextButton(
                onPressed: _imageSize == null || _saving
                    ? null
                    : () => setState(() {
                        _edit = ImageEdit(rotation: _edit.rotation);
                      }),
                child: const Text('全图'),
              ),
              Text(
                _panMode ? '双指缩放，拖动画面' : '拖动角点/边框调整，拖动框内移动',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _cropDescription {
    if (_imageSize == null) return '正在读取原图';
    final rect = _edit.cropFor(_imageSize!);
    final dimensions = _edit.rotation % 180 == 0
        ? rect.size
        : Size(rect.height, rect.width);
    return '${dimensions.width.round()} × ${dimensions.height.round()} 像素 · ${_edit.rotation}°';
  }

  List<Widget> _cropOverlay(Rect painted) {
    final crop = _edit.cropFor(_imageSize!);
    final scale = painted.width / _imageSize!.width;
    final zoom = _transform.value.getMaxScaleOnAxis();
    final handleSize = 44 / zoom;
    final edgeSize = 32 / zoom;
    final rect = Rect.fromLTWH(
      painted.left + crop.left * scale,
      painted.top + crop.top * scale,
      crop.width * scale,
      crop.height * scale,
    );
    return [
      Positioned.fill(
        child: IgnorePointer(child: CustomPaint(painter: _CropPainter(rect))),
      ),
      if (!_panMode && !_saving) ...[
        _zone(
          rect.deflate(math.min(20 / zoom, rect.shortestSide / 4)),
          _DragTarget.move,
          scale,
        ),
        _zone(
          Rect.fromCenter(
            center: rect.topCenter,
            width: rect.width,
            height: edgeSize,
          ),
          _DragTarget.top,
          scale,
        ),
        _zone(
          Rect.fromCenter(
            center: rect.bottomCenter,
            width: rect.width,
            height: edgeSize,
          ),
          _DragTarget.bottom,
          scale,
        ),
        _zone(
          Rect.fromCenter(
            center: rect.centerLeft,
            width: edgeSize,
            height: rect.height,
          ),
          _DragTarget.left,
          scale,
        ),
        _zone(
          Rect.fromCenter(
            center: rect.centerRight,
            width: edgeSize,
            height: rect.height,
          ),
          _DragTarget.right,
          scale,
        ),
        for (final corner in {
          _DragTarget.topLeft: rect.topLeft,
          _DragTarget.topRight: rect.topRight,
          _DragTarget.bottomLeft: rect.bottomLeft,
          _DragTarget.bottomRight: rect.bottomRight,
        }.entries)
          _zone(
            Rect.fromCenter(
              center: corner.value,
              width: handleSize,
              height: handleSize,
            ),
            corner.key,
            scale,
            corner: true,
          ),
      ],
    ];
  }

  Offset _local(Offset global) =>
      (_canvasKey.currentContext!.findRenderObject() as RenderBox)
          .globalToLocal(global);

  Widget _zone(
    Rect rect,
    _DragTarget target,
    double scale, {
    bool corner = false,
  }) => Positioned.fromRect(
    rect: rect,
    child: GestureDetector(
      key: ValueKey('crop-${target.name}'),
      dragStartBehavior: DragStartBehavior.down,
      behavior: HitTestBehavior.opaque,
      onPanStart: (d) {
        _dragStart = _local(d.globalPosition);
        _dragCrop = _edit.cropFor(_imageSize!);
      },
      onPanUpdate: (d) =>
          _drag(target, (_local(d.globalPosition) - _dragStart!) / scale),
      child: corner
          ? Center(
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.blue, width: 2),
                ),
              ),
            )
          : null,
    ),
  );

  void _drag(_DragTarget target, Offset delta) {
    final original = _dragCrop!;
    final size = _imageSize!;
    final minW = math.min(16.0, original.width);
    final minH = math.min(16.0, original.height);
    double left = original.left,
        top = original.top,
        right = original.right,
        bottom = original.bottom;
    if (target == _DragTarget.move) {
      final dx = delta.dx.clamp(-left, size.width - right);
      final dy = delta.dy.clamp(-top, size.height - bottom);
      left += dx;
      right += dx;
      top += dy;
      bottom += dy;
    } else {
      if ([
        _DragTarget.left,
        _DragTarget.topLeft,
        _DragTarget.bottomLeft,
      ].contains(target)) {
        left = (left + delta.dx).clamp(0, right - minW);
      }
      if ([
        _DragTarget.top,
        _DragTarget.topLeft,
        _DragTarget.topRight,
      ].contains(target)) {
        top = (top + delta.dy).clamp(0, bottom - minH);
      }
      if ([
        _DragTarget.right,
        _DragTarget.topRight,
        _DragTarget.bottomRight,
      ].contains(target)) {
        right = (right + delta.dx).clamp(left + minW, size.width);
      }
      if ([
        _DragTarget.bottom,
        _DragTarget.bottomLeft,
        _DragTarget.bottomRight,
      ].contains(target)) {
        bottom = (bottom + delta.dy).clamp(top + minH, size.height);
      }
    }
    setState(
      () => _edit = ImageEdit(
        rotation: _edit.rotation,
        crop: Rect.fromLTRB(left, top, right, bottom),
      ),
    );
  }
}

class _CropPainter extends CustomPainter {
  final Rect rect;
  _CropPainter(this.rect);

  @override
  void paint(Canvas canvas, Size size) {
    final mask = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(rect);
    canvas.drawPath(mask, Paint()..color = Colors.black54);
    canvas.drawRect(
      rect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final grid = Paint()
      ..color = Colors.white38
      ..strokeWidth = 0.5;
    for (var i = 1; i < 3; i++) {
      final x = rect.left + rect.width * i / 3,
          y = rect.top + rect.height * i / 3;
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), grid);
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), grid);
    }
  }

  @override
  bool shouldRepaint(_CropPainter old) => old.rect != rect;
}
