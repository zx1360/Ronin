// 媒体网格单元: 画廊三种预览模式 (缩略 / 等比 / 瀑布流) 共用同一个单元组件。
// 三种模式只在「图片如何定尺寸」上不同; 本地文件解析与缓存、占位与错误态、
// 选中与角标叠层、点击/长按/双击回调完全一致, 因此只写一遍.
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/gallery/models/media_asset.dart';
import 'package:torrid/features/gallery/providers/gallery_providers.dart';

part 'intrinsic_height_capped.dart';

/// 单元的布局形态
enum MediaGridCellLayout {
  /// 缩略图网格: 解码时就地缩到 150px, 图片铺满方形单元
  thumb,

  /// 等比预览: 行内等高, 图片按原始宽高比居中
  proportional,

  /// 瀑布流: 单元按图片原始宽高比撑高, 尺寸就绪后动画过渡
  waterfall,
}

/// 本地图片文件解析: (资源, 是否优先预览图) → 文件
typedef MediaGridFileResolver = Future<File?> Function(
  MediaAsset asset, {
  required bool preview,
});

/// 图片文件缓存, 同一路径不重复做文件系统检查.
/// 键带 `thumb:` / `preview:` 前缀: 两类图的相对路径可能是同一个字符串.
final Map<String, File?> _fileCache = {};

/// 允许的最大高宽比, 极高的图片不撑开整行
const double _kMaxAspectRatio = 4.0;

/// 图片尺寸未知时的默认高宽比, 避免瀑布流布局跳变
const double _kFallbackAspectRatio = 0.75;

class MediaGridCell extends ConsumerStatefulWidget {
  const MediaGridCell({
    super.key,
    required this.asset,
    required this.layout,
    required this.isSelected,
    required this.isCurrent,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
    this.selectionIndex,
    this.onDoubleTap,
    this.hasTags = false,
    this.cellWidth,
    this.resolveFile,
  });

  final MediaAsset asset;
  final MediaGridCellLayout layout;

  /// 瀑布流单列宽度 (决定单元高度); 另两种布局的尺寸由父级约束
  final double? cellWidth;

  final bool isSelected;

  /// 是否为当前检阅项 (父级用 GlobalKey 定位它)
  final bool isCurrent;
  final bool isSelectionMode;
  final int? selectionIndex;

  /// 是否有标签, 仅非选择模式显示标签角标
  final bool hasTags;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onDoubleTap;

  /// 本地文件解析方式; 默认走 [galleryStorageProvider], 组件测试用它注入文件
  final MediaGridFileResolver? resolveFile;

  @override
  ConsumerState<MediaGridCell> createState() => _MediaGridCellState();
}

class _MediaGridCellState extends ConsumerState<MediaGridCell> {
  File? _file;
  bool _isLoading = true;

  /// 图片原始像素尺寸, 仅瀑布流用来算单元高度
  Size? _imageSize;

  /// 等比/瀑布流优先用预览图, 缩略图网格只用缩略图 (与解码尺寸口径一致)
  bool get _preferPreview => widget.layout != MediaGridCellLayout.thumb;

  /// 图片圆角, 瀑布流裁剪图片, 选中框跟随
  BorderRadius get _radius => widget.layout == MediaGridCellLayout.waterfall
      ? BorderRadius.circular(2)
      : BorderRadius.zero;

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  @override
  void didUpdateWidget(MediaGridCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当前检阅项的 GlobalKey 会在单元之间移动, 状态被复用, 必须跟着换图
    if (oldWidget.asset.id != widget.asset.id) {
      _imageSize = null;
      _loadFile();
    }
  }

  Future<void> _loadFile() async {
    final asset = widget.asset;
    final path =
        _preferPreview ? asset.previewPath ?? asset.thumbPath : asset.thumbPath;
    final key =
        '${_preferPreview ? 'preview' : 'thumb'}:${path ?? asset.filePath}';

    if (_fileCache.containsKey(key)) {
      _applyLoaded(_fileCache[key]);
      return;
    }
    if (path == null) {
      _applyLoaded(null); // 没有本地缓存路径, 不必触达存储层
      return;
    }

    final resolver = widget.resolveFile;
    final file = resolver != null
        ? await resolver(asset, preview: _preferPreview)
        : await _loadFromStorage(asset);
    _fileCache[key] = file;
    _applyLoaded(file);
  }

  Future<File?> _loadFromStorage(MediaAsset asset) async {
    final storage = ref.read(galleryStorageProvider);
    if (_preferPreview && asset.previewPath != null) {
      final preview = await storage.getPreviewFile(asset.previewPath!);
      if (preview != null) return preview;
    }
    if (asset.thumbPath != null) {
      return storage.getThumbFile(asset.thumbPath!);
    }
    return null;
  }

  void _applyLoaded(File? file) {
    if (!mounted) return;
    setState(() {
      _file = file;
      _isLoading = false;
    });
  }

  /// 瀑布流单元高度: 按图片原始宽高比, 尺寸未知时用默认比例
  double get _waterfallHeight {
    final width = widget.cellWidth ?? 0;
    final size = _imageSize;
    if (size == null || width <= 0 || size.width <= 0) {
      return width * _kFallbackAspectRatio;
    }
    return min(width / (size.width / size.height), width * _kMaxAspectRatio);
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.asset;
    final primary = Theme.of(context).colorScheme.primary;

    Widget body = Stack(
      // 缩略图网格由 SliverGrid 给出方形紧约束, 单元必须铺满
      fit: widget.layout == MediaGridCellLayout.thumb
          ? StackFit.expand
          : StackFit.loose,
      children: [
        _buildImage(),
        if (widget.isSelected)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: _radius,
                border: Border.all(color: primary, width: 3),
              ),
            ),
          ),
        if (widget.isCurrent && !widget.isSelectionMode)
          Positioned(
            bottom: 4,
            right: 4,
            child: _badge(Icons.visibility, Colors.blue, iconSize: 16),
          ),
        if (!widget.isSelectionMode && asset.editParams != null)
          Positioned(
            top: 4,
            right: 4,
            child: _badge(
              Icons.edit,
              Colors.black54,
              iconSize: 14,
              padding: const EdgeInsets.all(2),
              iconColor: Colors.amber,
            ),
          ),
        if (widget.isSelectionMode)
          Positioned(top: 4, right: 4, child: _buildSelectionDot(primary)),
        if (asset.isDeleted)
          Positioned(
            top: 4,
            left: 4,
            child: _badge(
              Icons.delete,
              Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            ),
          ),
        if (asset.groupId != null)
          Positioned(
            bottom: 4,
            left: 4,
            child: _badge(Icons.layers, Colors.amber),
          ),
        if (widget.hasTags && !widget.isSelectionMode)
          Positioned(
            bottom: 4,
            left: asset.groupId != null ? 24 : 4,
            child: _badge(Icons.label_outline, Colors.teal),
          ),
        if (asset.isVideo)
          const Positioned(
            bottom: 4,
            right: 4,
            child: Icon(
              Icons.play_circle_outline,
              color: Colors.white,
              size: 24,
            ),
          ),
      ],
    );

    if (widget.layout == MediaGridCellLayout.waterfall) {
      body = AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: body,
      );
    }

    return RepaintBoundary(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        onLongPress: widget.onLongPress,
        child: body,
      ),
    );
  }

  Widget _buildImage() {
    final file = _file;
    if (_isLoading || file == null) return _buildPlaceholder();

    switch (widget.layout) {
      case MediaGridCellLayout.thumb:
        return Image.file(
          file,
          fit: BoxFit.cover,
          cacheWidth: 150,
          cacheHeight: 150,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        );
      case MediaGridCellLayout.proportional:
        return Center(
          child: _IntrinsicHeightCapped(
            maxAspectRatio: _kMaxAspectRatio,
            child: Image.file(
              file,
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
            ),
          ),
        );
      case MediaGridCellLayout.waterfall:
        final image = Image.file(
          file,
          fit: BoxFit.cover,
          width: widget.cellWidth,
          height: _waterfallHeight,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        );
        _measureImage(image);
        return ClipRRect(borderRadius: _radius, child: image);
    }
  }

  /// 捕获图片实际尺寸; 只挂一次监听, 尺寸已知后不再重复挂
  void _measureImage(Image image) {
    if (_imageSize != null) return;
    final stream = image.image.resolve(const ImageConfiguration());
    stream.addListener(ImageStreamListener((info, _) {
      final size = Size(
        info.image.width.toDouble(),
        info.image.height.toDouble(),
      );
      if (size.width <= 0 || size.height <= 0) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _imageSize = size);
      });
    }));
  }

  /// 选择模式的选中圆点: 已选显示序号, 未选为空
  Widget _buildSelectionDot(Color primary) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: widget.isSelected ? primary : Colors.black54,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: widget.isSelected
          ? Center(
              child: Text(
                widget.selectionIndex?.toString() ?? '✓',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
    );
  }

  /// 角标: 圆角小方块 + 图标
  Widget _badge(
    IconData icon,
    Color color, {
    double iconSize = 12,
    Color iconColor = Colors.white,
    EdgeInsets padding = const EdgeInsets.all(4),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(icon, color: iconColor, size: iconSize),
    );
  }

  Widget _buildPlaceholder() {
    // 瀑布流的占位要占满已算出的单元高度; 等比模式的占位固定为正方形, 行高不跳变
    final isWaterfall = widget.layout == MediaGridCellLayout.waterfall;
    final box = Container(
      width: isWaterfall ? widget.cellWidth : double.infinity,
      height: isWaterfall ? _waterfallHeight : null,
      color: Colors.grey[800],
      child: Icon(
        widget.asset.isVideo ? Icons.videocam : Icons.image,
        color: Colors.grey[600],
      ),
    );
    return widget.layout == MediaGridCellLayout.proportional
        ? AspectRatio(aspectRatio: 1.0, child: box)
        : box;
  }
}
