import 'package:flutter/material.dart';

/// 快速滚动条轨道宽度
const double kGalleryScrollbarTrackWidth = 8;
/// 快速滚动条在滚动视图右侧的总占宽（轨道 + 边距）
const double kGalleryScrollbarReservedWidth = kGalleryScrollbarTrackWidth + 4;

/// 可拖拽快速滚动包装器
/// 在右侧显示一个可拖拽的滚动指示条，类似手机相册的快速滚动功能
class GalleryScrollWrapper extends StatefulWidget {
  final Widget child;
  final ScrollController scrollController;
  final int itemCount;
  final int crossAxisCount;

  const GalleryScrollWrapper({
    super.key,
    required this.child,
    required this.scrollController,
    required this.itemCount,
    required this.crossAxisCount,
  });

  @override
  State<GalleryScrollWrapper> createState() => _GalleryScrollWrapperState();
}

class _GalleryScrollWrapperState extends State<GalleryScrollWrapper> {
  bool _isDragging = false;
  double _thumbTop = 0;
  double _thumbHeight = 0;
  double _trackHeight = 0;

  static const double _trackWidth = kGalleryScrollbarTrackWidth;
  static const double _thumbMinHeight = 32;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(GalleryScrollWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_onScroll);
      widget.scrollController.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!_isDragging && mounted) {
      _updateThumbPosition();
    }
  }

  void _updateThumbPosition() {
    if (!widget.scrollController.hasClients) return;
    final position = widget.scrollController.position;
    if (!position.hasContentDimensions) return;

    final maxScroll = position.maxScrollExtent;
    final viewport = position.viewportDimension;
    final totalContent = maxScroll + viewport;

    if (totalContent <= 0) return;

    final ratio = viewport / totalContent;
    final thumbH = (ratio * _trackHeight).clamp(_thumbMinHeight, _trackHeight);
    final scrollRatio = maxScroll > 0 ? position.pixels / maxScroll : 0.0;
    final maxThumbTop = _trackHeight - thumbH;
    final thumbT = scrollRatio * maxThumbTop;

    setState(() {
      _thumbHeight = thumbH;
      _thumbTop = thumbT;
    });
  }

  void _onDragStart(DragStartDetails details) {
    _isDragging = true;
    _onDragUpdate(DragUpdateDetails(
      globalPosition: details.globalPosition,
      delta: Offset.zero,
    ));
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!widget.scrollController.hasClients) return;
    final position = widget.scrollController.position;
    final maxScroll = position.maxScrollExtent;
    if (maxScroll <= 0) return;

    final maxThumbTop = _trackHeight - _thumbHeight;
    if (maxThumbTop <= 0) return;

    final RenderBox box = context.findRenderObject() as RenderBox;
    final localPos = box.globalToLocal(details.globalPosition);
    final ratio = (localPos.dy / _trackHeight).clamp(0.0, 1.0);
    final targetOffset = ratio * maxScroll;

    widget.scrollController.jumpTo(targetOffset.clamp(0.0, maxScroll));
    _updateThumbPosition();
  }

  void _onDragEnd(DragEndDetails details) {
    _isDragging = false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _trackHeight = constraints.maxHeight;
        if (_thumbHeight == 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _updateThumbPosition();
          });
        }

        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: _trackWidth + 4),
              child: widget.child,
            ),
            Positioned(
              right: 2,
              top: 0,
              bottom: 0,
              child: GestureDetector(
                onVerticalDragStart: _onDragStart,
                onVerticalDragUpdate: _onDragUpdate,
                onVerticalDragEnd: _onDragEnd,
                child: Container(
                  width: _trackWidth,
                  color: Colors.transparent,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 2,
                        right: 2,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: _thumbTop,
                        child: Container(
                          height: _thumbHeight,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: _isDragging
                                ? Colors.white.withValues(alpha: 0.7)
                                : Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
