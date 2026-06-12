part of '../../pages/medias_browser_page.dart';

/// 预览图文件缓存 (避免重复的文件系统检查)
final Map<String, File?> _previewCache = {};

/// 瀑布流单元格 (模式三)
///
/// 显示预览图并保持原始宽高比。通过 [ImageStreamListener] 捕获图片实际尺寸，
/// 计算出符合宽高比上限 (max 4×) 的显示高度。
class _WaterfallCell extends ConsumerStatefulWidget {
  final MediaAsset asset;
  final double cellWidth;
  final bool isSelected;
  final bool isCurrent;
  final int? selectionIndex;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onDoubleTap;

  const _WaterfallCell({
    super.key,
    required this.asset,
    required this.cellWidth,
    required this.isSelected,
    required this.isCurrent,
    this.selectionIndex,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
    this.onDoubleTap,
  });

  @override
  ConsumerState<_WaterfallCell> createState() => _WaterfallCellState();
}

class _WaterfallCellState extends ConsumerState<_WaterfallCell> {
  File? _previewFile;
  bool _isLoading = true;
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  @override
  void didUpdateWidget(_WaterfallCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id) {
      _loadPreview();
    }
  }

  Future<void> _loadPreview() async {
    final cacheKey = widget.asset.previewPath ?? widget.asset.thumbPath ?? widget.asset.filePath;

    if (_previewCache.containsKey(cacheKey)) {
      if (mounted) {
        setState(() {
          _previewFile = _previewCache[cacheKey];
          _isLoading = false;
        });
      }
      return;
    }

    final storage = ref.read(galleryStorageProvider);
    File? file;

    if (widget.asset.previewPath != null) {
      file = await storage.getPreviewFile(widget.asset.previewPath!);
    }
    if (file == null && widget.asset.thumbPath != null) {
      file = await storage.getThumbFile(widget.asset.thumbPath!);
    }

    _previewCache[cacheKey] = file;

    if (mounted) {
      setState(() {
        _previewFile = file;
        _isLoading = false;
      });
    }
  }

  double? _displayHeight() {
    if (_imageSize == null || widget.cellWidth <= 0) return null;
    final aspectRatio = _imageSize!.width / _imageSize!.height;
    if (aspectRatio <= 0) return null;
    final rawHeight = widget.cellWidth / aspectRatio;
    return min(rawHeight, widget.cellWidth * 4);
  }

  @override
  Widget build(BuildContext context) {
    final displayH = _displayHeight();

    return RepaintBoundary(
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        onLongPress: widget.onLongPress,
        child: Stack(
          children: [
            if (_isLoading)
              _buildPlaceholder(displayH ?? widget.cellWidth)
            else if (_previewFile != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: _buildImage(displayH),
              )
            else
              _buildPlaceholder(displayH ?? widget.cellWidth),

            if (widget.isSelected)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 3,
                    ),
                  ),
                ),
              ),

            if (widget.isCurrent && !widget.isSelectionMode)
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.visibility, color: Colors.white, size: 16),
                ),
              ),

            if (!widget.isSelectionMode && widget.asset.editParams != null)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.edit, color: Colors.amber, size: 14),
                ),
              ),

            if (widget.isSelectionMode)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: widget.isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.black54,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: widget.isSelected
                      ? Center(
                          child: Text(
                            widget.selectionIndex?.toString() ?? '✓',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        )
                      : null,
                ),
              ),

            if (widget.asset.isDeleted)
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.delete, color: Colors.white, size: 12),
                ),
              ),

            if (widget.asset.groupId != null)
              Positioned(
                bottom: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.layers, color: Colors.white, size: 12),
                ),
              ),

            if (widget.asset.isVideo)
              const Positioned(
                bottom: 4,
                right: 4,
                child: Icon(Icons.play_circle_outline, color: Colors.white, size: 24),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(double? displayH) {
    final img = Image.file(
      _previewFile!,
      fit: BoxFit.cover,
      width: widget.cellWidth,
      height: displayH,
      errorBuilder: (context, error, stack) => _buildPlaceholder(displayH ?? widget.cellWidth),
    );

    final resolved = img.image.resolve(const ImageConfiguration());
    resolved.addListener(ImageStreamListener((info, _) {
      final sz = Size(info.image.width.toDouble(), info.image.height.toDouble());
      if (_imageSize != sz && sz.width > 0 && sz.height > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _imageSize = sz);
        });
      }
    }));

    return img;
  }

  Widget _buildPlaceholder(double height) {
    return Container(
      width: widget.cellWidth,
      height: height,
      color: Colors.grey[800],
      child: Icon(
        widget.asset.isVideo ? Icons.videocam : Icons.image,
        color: Colors.grey[600],
      ),
    );
  }
}
