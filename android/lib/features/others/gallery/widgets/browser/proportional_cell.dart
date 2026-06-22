part of '../../pages/medias_browser_page.dart';

/// 等比预览单元格 (模式二)
///
/// 显示预览图，通过 [_IntrinsicHeightCapped] 限制宽高比上限 (max 4×)。
/// 配合 [IntrinsicHeight] 行布局实现行内等高 + 垂直居中。
class _ProportionalCell extends ConsumerStatefulWidget {
  final MediaAsset asset;
  final bool isSelected;
  final bool isCurrent;
  final int? selectionIndex;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onDoubleTap;
  final bool hasTags;

  const _ProportionalCell({
    super.key,
    required this.asset,
    required this.isSelected,
    required this.isCurrent,
    this.selectionIndex,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
    this.onDoubleTap,
    this.hasTags = false,
  });

  @override
  ConsumerState<_ProportionalCell> createState() => _ProportionalCellState();
}

class _ProportionalCellState extends ConsumerState<_ProportionalCell> {
  File? _previewFile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  @override
  void didUpdateWidget(_ProportionalCell oldWidget) {
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

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        onLongPress: widget.onLongPress,
        child: Stack(
          children: [
            // 加载占位符.
            if (_isLoading)
              _buildPlaceholder()
            else if (_previewFile != null)
              Center(
                child: _IntrinsicHeightCapped(
                  maxAspectRatio: 4.0,
                  child: Image.file(
                    _previewFile!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (context, error, stack) => _buildPlaceholder(),
                  ),
                ),
              )
            else
              _buildPlaceholder(),

            if (widget.isSelected)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
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
                left: widget.hasTags ? 24: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.layers, color: Colors.white, size: 12),
                ),
              ),

            if (widget.hasTags && !widget.isSelectionMode)
              Positioned(
                bottom: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.teal,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.label_outline, color: Colors.white, size: 12),
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

  Widget _buildPlaceholder() {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        width: double.infinity,
        color: Colors.grey[800],
        child: Icon(
          widget.asset.isVideo ? Icons.videocam : Icons.image,
          color: Colors.grey[600],
        ),
      ),
    );
  }
}
