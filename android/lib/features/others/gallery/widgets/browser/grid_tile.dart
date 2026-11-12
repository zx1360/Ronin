part of '../../pages/medias_browser_page.dart';

class _GridTile extends ConsumerStatefulWidget {
  final MediaAsset asset;
  final bool usePreview, isSelected, isCurrent, isSelectionMode, hasTags;
  final String? previewPath;
  final int? selectionIndex;
  final VoidCallback onTap, onLongPress;

  const _GridTile({
    super.key,
    required this.asset,
    this.usePreview = false,
    this.previewPath,
    required this.isSelected,
    required this.isCurrent,
    this.selectionIndex,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
    this.hasTags = false,
  });

  @override
  ConsumerState<_GridTile> createState() => _GridTileState();
}

class _GridTileState extends ConsumerState<_GridTile> {
  File? _thumbnail;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(_GridTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.thumbPath != widget.asset.thumbPath ||
        (oldWidget.usePreview && !widget.usePreview)) {
      _loadThumbnail();
    }
  }

  Future<void> _loadThumbnail() async {
    final path = widget.asset.thumbPath;
    if (widget.usePreview || path == null) return;
    File? file;
    try {
      file = await ref.read(galleryStorageProvider).getThumbFile(path);
    } catch (_) {}
    if (mounted && widget.asset.thumbPath == path) {
      setState(() => _thumbnail = file);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(galleryFilesRevisionProvider, (_, _) => _loadThumbnail());
    return LayoutBuilder(
      builder: (context, constraints) {
        final file = widget.usePreview
            ? (widget.previewPath == null ? null : File(widget.previewPath!))
            : _thumbnail;
        final details = constraints.maxWidth >= 48;
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final border = widget.isSelected
            ? Theme.of(context).colorScheme.primary
            : widget.isCurrent
            ? Colors.lightBlueAccent
            : null;
        return RepaintBoundary(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            onDoubleTap: widget.asset.isDeleted ? _undoDelete : null,
            onLongPress: widget.onLongPress,
            child: ColoredBox(
              color: const Color(0xFF191A1D),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (file != null)
                    Image(
                      image: ResizeImage(
                        FileImage(file),
                        width: (constraints.maxWidth * dpr).ceil().clamp(
                          1,
                          1440,
                        ),
                        height: (constraints.maxHeight * dpr).ceil().clamp(
                          1,
                          2560,
                        ),
                        policy: ResizeImagePolicy.fit,
                      ),
                      fit: widget.usePreview ? BoxFit.contain : BoxFit.cover,
                      errorBuilder: (_, _, _) => _placeholder(),
                    )
                  else
                    _placeholder(),
                  if (widget.asset.isDeleted)
                    const ColoredBox(color: Color(0x66000000)),
                  if (border != null)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: border, width: 2),
                      ),
                    ),
                  if (details) ...[
                    _GroupBadge(asset: widget.asset),
                    if (widget.asset.isDeleted)
                      _badge(Icons.delete_outline, Colors.redAccent, left: 4),
                    if (!widget.isSelectionMode &&
                        widget.asset.editParams != null)
                      _badge(Icons.edit_outlined, Colors.amber, right: 4),
                    if (widget.hasTags && !widget.isSelectionMode)
                      _badge(
                        Icons.label_outline,
                        Colors.tealAccent,
                        left: 4,
                        bottom: 4,
                      ),
                    if (widget.asset.isVideo)
                      _badge(
                        Icons.play_circle_outline,
                        Colors.white,
                        right: 4,
                        bottom: 4,
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
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: widget.isSelected
                              ? Center(
                                  child: FittedBox(
                                    child: Text(
                                      '${widget.selectionIndex}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _placeholder() => Center(
    child: Icon(
      widget.asset.isVideo ? Icons.videocam_outlined : Icons.image_outlined,
      color: Colors.white24,
      size: 20,
    ),
  );

  Widget _badge(
    IconData icon,
    Color color, {
    double? left,
    double? right,
    double? bottom,
  }) => Positioned(
    left: left,
    right: right,
    bottom: bottom,
    top: bottom == null ? 4 : null,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Icon(icon, color: color, size: 14),
      ),
    ),
  );

  Future<void> _undoDelete() async {
    try {
      await ref
          .read(mediaAssetListProvider.notifier)
          .markDeleted(widget.asset.id, deleted: false);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('恢复失败：$error')));
      }
    }
  }
}

class _GroupBadge extends ConsumerWidget {
  final MediaAsset asset;
  const _GroupBadge({required this.asset});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count =
        ref.watch(mediaGroupSizesProvider).value?[asset.groupId ?? asset.id] ??
        0;
    if (count < 2) return const SizedBox.shrink();
    return Positioned(
      top: asset.isDeleted ? 26 : 4,
      left: 4,
      child: Tooltip(
        message: '分组共 $count 项，可在浏览页进入组内',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(4),
          ),
          child: FittedBox(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.layers_outlined,
                  size: 12,
                  color: Colors.amber,
                ),
                const SizedBox(width: 3),
                Text(
                  '$count',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
