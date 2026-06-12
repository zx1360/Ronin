part of '../../pages/medias_browser_page.dart';

/// 缩略图文件缓存 (避免重复的文件系统检查)
final Map<String, File?> _thumbnailCache = {};

/// 网格项 - 使用 StatefulWidget 避免每次重建时重新加载缩略图
class _GridTile extends ConsumerStatefulWidget {
  final MediaAsset asset;
  final bool isSelected;
  final bool isCurrent;
  final int? selectionIndex;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _GridTile({
    super.key,
    required this.asset,
    required this.isSelected,
    required this.isCurrent,
    this.selectionIndex,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  ConsumerState<_GridTile> createState() => _GridTileState();
}

class _GridTileState extends ConsumerState<_GridTile> {
  File? _thumbnailFile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    final cacheKey = widget.asset.thumbPath ?? widget.asset.filePath;

    if (_thumbnailCache.containsKey(cacheKey)) {
      if (mounted) {
        setState(() {
          _thumbnailFile = _thumbnailCache[cacheKey];
          _isLoading = false;
        });
      }
      return;
    }

    final storage = ref.read(galleryStorageProvider);
    File? file;

    if (widget.asset.thumbPath != null) {
      file = await storage.getThumbFile(widget.asset.thumbPath!);
    }

    _thumbnailCache[cacheKey] = file;

    if (mounted) {
      setState(() {
        _thumbnailFile = file;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.asset.isDeleted ? () => _undoDelete() : null,
        onLongPress: widget.onLongPress,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_isLoading)
              _buildPlaceholder()
            else if (_thumbnailFile != null)
              Image.file(
                _thumbnailFile!,
                fit: BoxFit.cover,
                cacheWidth: 150,
                cacheHeight: 150,
                errorBuilder: (context, error, stack) => _buildPlaceholder(),
              )
            else
              _buildPlaceholder(),

            if (widget.isSelected)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 3,
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

  Future<void> _undoDelete() async {
    await ref.read(mediaAssetListProvider.notifier).markDeleted(widget.asset.id, deleted: false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已恢复: ${widget.asset.filePath.split('/').last}'), duration: const Duration(milliseconds: 400)),
      );
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[800],
      child: Icon(
        widget.asset.isVideo ? Icons.videocam : Icons.image,
        color: Colors.grey[600],
      ),
    );
  }
}
