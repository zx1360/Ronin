import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:torrid/core/widgets/async_value_widget/async_value_widget.dart';

import 'package:torrid/features/others/comic/models/chapter_info.dart';
import 'package:torrid/features/others/comic/models/comic_info.dart';

import 'package:torrid/features/others/comic/provider/notifier_provider.dart';
import 'package:torrid/features/others/comic/provider/online_status_provider.dart';

import 'package:torrid/features/others/comic/services/save_service.dart';

import 'package:torrid/features/others/comic/widgets/comic_browse/bottom_bar.dart';
import 'package:torrid/features/others/comic/widgets/comic_browse/comic_image.dart';
import 'package:torrid/features/others/comic/widgets/comic_browse/top_bar.dart';

import 'package:torrid/core/services/debug/logging_service.dart';
import 'package:torrid/core/modals/snack_bar.dart';
import 'package:torrid/features/others/comic/common/controls_auto_hide_mixin.dart';
import 'package:torrid/features/others/comic/common/reader_utils.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

class ComicScrollPage extends ConsumerStatefulWidget {
  final ComicInfo comicInfo;
  final List<ChapterInfo> chapters;
  final int chapterIndex;
  final bool isLocal;

  const ComicScrollPage({
    super.key,
    required this.comicInfo,
    required this.chapters,
    required this.chapterIndex,
    required this.isLocal,
  });

  @override
  ConsumerState<ComicScrollPage> createState() => _ComicScrollPageState();
}

class _ComicScrollPageState extends ConsumerState<ComicScrollPage>
    with ControlsAutoHideMixin<ComicScrollPage> {
  // 为了使ListView的跳转正常.  使用globalKey使每次刷新重新构建, 防止遗留信息阻止正常显示.
  Key _listviewKey = UniqueKey();
  // comic信息相关
  late List<ChapterInfo> chapters = widget.chapters;
  late int chapterIndex = widget.chapterIndex;
  late ChapterInfo currentChapter = chapters[chapterIndex];
  late List<Map<String, dynamic>> images = currentChapter.images;
  late int imageCount = effectiveImageCount(currentChapter);

  // 状态量
  int _currentImageIndex = 0;
  bool _isMerging = false;
  bool _isCustomRangeSelecting = false;
  double? _customRangeStartOffset;
  bool _viewerInteracting = false;
  bool _zoomGestureMode = false;
  int _activePointerCount = 0;
  bool _isApplyingTransformClamp = false;

  // 实现交互界面
  final ScrollController _scrollController = ScrollController();
  final TransformationController _zoomController = TransformationController();

  /// 用于存储每一张图片在列表中的累计高度，方便快速计算滚动位置
  final List<double> _imageOffsets = [];

  @override
  void initState() {
    super.initState();
    init();
    // 初始化滚动监听器
    _scrollController.addListener(_onScroll);
    _zoomController.addListener(_onZoomMatrixChanged);
  }

  @override
  void dispose() {
    disposeControlsTimer();
    _scrollController.removeListener(_onScroll); // 移除监听器
    _zoomController.removeListener(_onZoomMatrixChanged);
    _scrollController.dispose();
    _zoomController.dispose();
    super.dispose();
  }

  /// 计算所有图片的高度和累计偏移量
  void _calculateImageOffsets() {
    final maxWidth = MediaQuery.of(context).size.width;
    // 抽离后的通用计算，便于维护
    _imageOffsets
      ..clear()
      ..addAll(computeImageOffsets(images, maxWidth));
  }

  void init() {
    ref
        .read(comicServiceProvider.notifier)
        .modifyComicPref(
          comicId: widget.comicInfo.id,
          chapterIndex: chapterIndex,
        );
    initializeControlsTimer();
  }

  // 初始化计时器
  // 由 ControlsAutoHideMixin 提供

  // 重置计时器
  // 由 ControlsAutoHideMixin 提供

  bool get _isZoomed {
    final scale = _zoomController.value.getMaxScaleOnAxis();
    return _zoomGestureMode || (scale - 1.0).abs() > 0.01;
  }

  bool get _shouldLockListScroll {
    // 仅在多指缩放过程中锁定 ListView，避免缩放手势被滚动抢占。
    return _activePointerCount > 1;
  }

  bool get _enableViewerPan {
    // 缩放后允许通过 InteractiveViewer 拖拽查看细节。
    return _isZoomed || _activePointerCount > 1;
  }

  void _onZoomMatrixChanged() {
    if (_isApplyingTransformClamp || !mounted) return;
    _clampViewerTransform();
  }

  void _clampViewerTransform() {
    if (!mounted) return;

    final matrix = _zoomController.value.clone();
    final scale = matrix.getMaxScaleOnAxis();
    final viewportSize = context.size;
    if (viewportSize == null) return;

    final viewportRect = Rect.fromLTWH(
      0,
      0,
      viewportSize.width,
      viewportSize.height,
    );
    final transformedRect = MatrixUtils.transformRect(matrix, viewportRect);

    // 回到初始缩放后，清空残留位移。
    if (scale <= 1.0001) {
      final hasOffset =
          matrix.storage[12].abs() > 0.01 || matrix.storage[13].abs() > 0.01;
      if (hasOffset) {
        _isApplyingTransformClamp = true;
        _zoomController.value = Matrix4.identity();
        _isApplyingTransformClamp = false;
      }
      return;
    }

    double dx = 0.0;

    // 当内容宽度大于屏幕时，保证左右都不露黑边。
    if (transformedRect.width > viewportRect.width + 0.01) {
      if (transformedRect.left > viewportRect.left) {
        dx = viewportRect.left - transformedRect.left;
      } else if (transformedRect.right < viewportRect.right) {
        dx = viewportRect.right - transformedRect.right;
      }
    } else {
      // 缩放后的内容宽度不足屏幕时，保持水平居中。
      dx = viewportRect.center.dx - transformedRect.center.dx;
    }

    // 纵向拖动交给 ListView，自身不保留纵向位移。
    final dy = viewportRect.top - transformedRect.top;

    final changed = dx.abs() > 0.01 || dy.abs() > 0.01;
    if (changed) {
      matrix.storage[12] += dx;
      matrix.storage[13] += dy;
      _isApplyingTransformClamp = true;
      _zoomController.value = matrix;
      _isApplyingTransformClamp = false;
    }
  }

  void _syncZoomGestureMode() {
    _clampViewerTransform();
    final scale = _zoomController.value.getMaxScaleOnAxis();
    final zoomedNow = (scale - 1.0).abs() > 0.01;
    if (zoomedNow == _zoomGestureMode || !mounted) return;
    setState(() {
      _zoomGestureMode = zoomedNow;
    });
  }

  void _onPointerDown(PointerDownEvent _) {
    final prev = _activePointerCount;
    _activePointerCount++;
    if (prev <= 1 && _activePointerCount > 1 && mounted) {
      setState(() {});
    }
  }

  void _onPointerUpOrCancel(PointerEvent _) {
    final prev = _activePointerCount;
    _activePointerCount = max(0, _activePointerCount - 1);
    if (prev > 1 && _activePointerCount <= 1 && mounted) {
      setState(() {});
    }
  }

  void _onViewerInteractionStart(ScaleStartDetails _) {
    if (!mounted || _viewerInteracting) return;
    setState(() {
      _viewerInteracting = true;
    });
  }

  void _onViewerInteractionUpdate(ScaleUpdateDetails _) {
    _syncZoomGestureMode();
  }

  void _onViewerInteractionEnd(ScaleEndDetails _) {
    if (!mounted) return;
    _clampViewerTransform();
    final scale = _zoomController.value.getMaxScaleOnAxis();
    final zoomedNow = (scale - 1.0).abs() > 0.01;
    setState(() {
      _viewerInteracting = false;
      _zoomGestureMode = zoomedNow;
    });
  }

  Future<bool> _restoreZoomBeforeSaveIfNeeded() async {
    if (!_isZoomed) return false;

    final anchorOffset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;
    _zoomController.value = Matrix4.identity();
    if (mounted) {
      setState(() {
        _zoomGestureMode = false;
        _viewerInteracting = false;
        _activePointerCount = 0;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final maxExtent = _scrollController.position.maxScrollExtent;
      final target = anchorOffset.clamp(0.0, maxExtent).toDouble();
      _scrollController.jumpTo(target);
    });

    if (mounted) {
      displaySnackBar(context, '已恢复默认缩放，请再次点击保存');
    }
    return true;
  }

  ({int startIndex, int endIndex}) _calculateVisibleRange({
    required double visibleTop,
    required double visibleBottom,
  }) {
    if (images.isEmpty || _imageOffsets.length < 2) {
      return (startIndex: 0, endIndex: 0);
    }

    int startIndex =
        _imageOffsets.indexWhere((offset) => offset > visibleTop) - 1;
    int endIndex =
        _imageOffsets.indexWhere((offset) => offset >= visibleBottom) - 1;

    startIndex = startIndex >= 0 ? startIndex : 0;
    endIndex = endIndex < 0 ? images.length - 1 : endIndex;
    if (endIndex < startIndex) {
      endIndex = startIndex;
    }

    return (startIndex: startIndex, endIndex: endIndex);
  }

  Future<Uint8List> _loadImageBytes(Map<String, dynamic> image) async {
    final rawPath = image['path']?.toString() ?? '';
    if (rawPath.isEmpty) {
      throw Exception('图片路径为空');
    }

    if (widget.isLocal) {
      final file = File(rawPath);
      if (!await file.exists()) {
        throw Exception('本地图片不存在: $rawPath');
      }
      return file.readAsBytes();
    }

    final normalizedPath = rawPath.startsWith('/')
        ? rawPath.substring(1)
        : rawPath;
    final response = await ref
        .read(apiClientManagerProvider)
        .getBinary('/static/$normalizedPath');
    if (response.statusCode != 200 || response.data == null) {
      throw Exception('在线图片下载失败: $rawPath');
    }
    return response.data!;
  }

  Uint8List _mergeSegmentsToPng(List<img.Image> segments) {
    if (segments.isEmpty) {
      throw Exception('没有可合并的图片内容');
    }

    final targetWidth = segments.first.width;
    final normalized = <img.Image>[];
    int totalHeight = 0;

    for (final segment in segments) {
      final normalizedSegment = segment.width == targetWidth
          ? segment
          : img.copyResize(segment, width: targetWidth);
      normalized.add(normalizedSegment);
      totalHeight += normalizedSegment.height;
    }

    final merged = img.Image(width: targetWidth, height: totalHeight);
    int currentY = 0;
    for (final segment in normalized) {
      img.compositeImage(merged, segment, dstX: 0, dstY: currentY);
      currentY += segment.height;
    }

    return Uint8List.fromList(img.encodePng(merged));
  }

  Future<Uint8List> _buildMergedBytesForWholeImages({
    required int startIndex,
    required int endIndex,
  }) async {
    final segments = <img.Image>[];
    for (int i = startIndex; i <= endIndex; i++) {
      final bytes = await _loadImageBytes(images[i]);
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        throw Exception('图片解码失败: ${images[i]['path']}');
      }
      segments.add(decoded);
    }
    return _mergeSegmentsToPng(segments);
  }

  List<_CropSegment> _collectCropSegments({
    required double startOffset,
    required double endOffset,
  }) {
    if (_imageOffsets.length < 2) return const [];

    final maxOffset = _imageOffsets.last;
    final clampedStart = startOffset.clamp(0.0, maxOffset).toDouble();
    final clampedEnd = endOffset.clamp(0.0, maxOffset).toDouble();
    if (clampedEnd <= clampedStart) return const [];

    final result = <_CropSegment>[];
    for (int i = 0; i < images.length; i++) {
      final imageTop = _imageOffsets[i];
      final imageBottom = _imageOffsets[i + 1];
      final overlapTop = max(imageTop, clampedStart);
      final overlapBottom = min(imageBottom, clampedEnd);
      if (overlapBottom <= overlapTop) continue;

      result.add(
        _CropSegment(
          imageIndex: i,
          displayTop: overlapTop - imageTop,
          displayBottom: overlapBottom - imageTop,
        ),
      );
    }
    return result;
  }

  Future<Uint8List> _buildMergedBytesForCroppedRange({
    required double startOffset,
    required double endOffset,
  }) async {
    final maxWidth = MediaQuery.of(context).size.width;
    final segments = _collectCropSegments(
      startOffset: startOffset,
      endOffset: endOffset,
    );
    if (segments.isEmpty) {
      throw Exception('选区内没有有效图片内容');
    }

    final croppedImages = <img.Image>[];
    for (final segment in segments) {
      final imageMeta = images[segment.imageIndex];
      final bytes = await _loadImageBytes(imageMeta);
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        throw Exception('图片解码失败: ${imageMeta['path']}');
      }

      final displayHeight = computeImageHeight(imageMeta, maxWidth);
      if (displayHeight <= 0) continue;

      final ratio = decoded.height / displayHeight;
      final topPx = (segment.displayTop * ratio)
          .round()
          .clamp(0, decoded.height - 1)
          .toInt();
      final bottomPx = (segment.displayBottom * ratio)
          .round()
          .clamp(topPx + 1, decoded.height)
          .toInt();

      final cropHeight = bottomPx - topPx;
      if (cropHeight <= 0) continue;

      final cropped = img.copyCrop(
        decoded,
        x: 0,
        y: topPx,
        width: decoded.width,
        height: cropHeight,
      );
      croppedImages.add(cropped);
    }

    if (croppedImages.isEmpty) {
      throw Exception('选区裁剪后没有有效内容');
    }

    return _mergeSegmentsToPng(croppedImages);
  }

  // 图片保存(连带上下的完整保存)
  Future<void> _saveWholeVisibleImages() async {
    if (images.isEmpty || _imageOffsets.length < 2) return;

    try {
      final screenHeight = MediaQuery.of(context).size.height;
      final visibleTop = _scrollController.offset;
      final visibleBottom = visibleTop + screenHeight;
      final range = _calculateVisibleRange(
        visibleTop: visibleTop,
        visibleBottom: visibleBottom,
      );

      final filename =
          "${widget.comicInfo.comicName}_第${currentChapter.chapterIndex}章_${range.startIndex + 1}-${range.endIndex + 1}.png";
      setState(() {
        _isMerging = true;
      });

      final mergedBytes = await _buildMergedBytesForWholeImages(
        startIndex: range.startIndex,
        endIndex: range.endIndex,
      );
      final saved = await ComicSaverService.saveImageBytesToPublic(
        mergedBytes,
        filename,
      );

      if (!mounted) return;
      if (saved) {
        displaySnackBar(context, "图片已保存: $filename");
      } else {
        displaySnackBar(context, '保存失败');
      }
    } catch (e) {
      if (mounted) {
        displaySnackBar(context, "保存失败: ${e.toString()}");
      }
      AppLogger().error("保存图片错误: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isMerging = false;
        });
      }
    }
  }

  Future<void> _saveCustomSelectedRange() async {
    if (images.isEmpty || _customRangeStartOffset == null) return;

    final startOffset = _customRangeStartOffset!;
    final endOffset =
        _scrollController.offset + MediaQuery.of(context).size.height;

    if (endOffset <= startOffset + 1) {
      displaySnackBar(context, '结束位置必须在起始位置之后');
      return;
    }

    final segments = _collectCropSegments(
      startOffset: startOffset,
      endOffset: endOffset,
    );
    if (segments.isEmpty) {
      displaySnackBar(context, '当前选区没有可保存内容');
      return;
    }

    final startIndex = segments.first.imageIndex;
    final endIndex = segments.last.imageIndex;
    final fileName =
        "${widget.comicInfo.comicName}_第${currentChapter.chapterIndex}章_${startIndex + 1}-${endIndex + 1}.png";

    try {
      setState(() {
        _isMerging = true;
      });

      final mergedBytes = await _buildMergedBytesForCroppedRange(
        startOffset: startOffset,
        endOffset: endOffset,
      );

      final saved = await ComicSaverService.saveImageBytesToPublic(
        mergedBytes,
        fileName,
      );

      if (!mounted) return;
      if (saved) {
        displaySnackBar(context, "图片已保存: $fileName");
      } else {
        displaySnackBar(context, '保存失败');
      }
    } catch (e) {
      if (mounted) {
        displaySnackBar(context, "保存失败: ${e.toString()}");
      }
      AppLogger().error('自定义区间保存失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isMerging = false;
          _isCustomRangeSelecting = false;
          _customRangeStartOffset = null;
        });
      }
    }
  }

  void _cancelCustomRangeSelection() {
    if (!_isCustomRangeSelecting) return;
    setState(() {
      _isCustomRangeSelecting = false;
      _customRangeStartOffset = null;
    });
    if (mounted) {
      displaySnackBar(context, '已取消自定义保存');
    }
  }

  Future<void> _onPrimarySavePressed() async {
    if (_isMerging) return;
    if (await _restoreZoomBeforeSaveIfNeeded()) return;

    if (_isCustomRangeSelecting) {
      _cancelCustomRangeSelection();
      return;
    }

    await _saveWholeVisibleImages();
  }

  Future<void> _onSecondarySavePressed() async {
    if (_isMerging || images.isEmpty) return;
    if (await _restoreZoomBeforeSaveIfNeeded()) return;
    if (!mounted) return;

    if (!_isCustomRangeSelecting) {
      setState(() {
        _isCustomRangeSelecting = true;
        _customRangeStartOffset = _scrollController.offset;
      });
      displaySnackBar(context, '起点已锁定，请滑动到末端后再次点击按钮');
      return;
    }

    await _saveCustomSelectedRange();
  }

  /// 滚动监听事件处理
  void _onScroll() {
    final currentOffset = _scrollController.offset;
    final newIndex = _calculateImageIndexAtOffset(currentOffset);

    if (newIndex != _currentImageIndex) {
      setState(() {
        _currentImageIndex = newIndex;
      });
    }
  }

  /// 根据滚动偏移量计算当前显示的图片索引
  int _calculateImageIndexAtOffset(double offset) {
    if (images.isEmpty || offset <= 0) return 0;

    for (int i = 1; i < _imageOffsets.length; i++) {
      if (offset < _imageOffsets[i]) {
        return i - 1;
      }
    }
    return images.length - 1;
  }

  /// 根据图片索引获取其在列表中的滚动偏移量
  double _getImageOffsetByIndex(int index) {
    if (index < 0 || index >= images.length) return 0.0;
    final targetOffset = _imageOffsets[index];
    final screenHeight = MediaQuery.of(context).size.height;
    final lastImageBottomOffset = _imageOffsets.last;
    return targetOffset + screenHeight > lastImageBottomOffset
        ? lastImageBottomOffset - screenHeight
        : targetOffset;
  }

  /// Slider 拖动事件处理
  void _onSlideFunc(double value) {
    if (images.isEmpty) return;

    final int newIndex = (value * images.length)
        .clamp(0, images.length - 1)
        .toInt();

    if (newIndex != _currentImageIndex) {
      setState(() {
        _currentImageIndex = newIndex;
      });
      // 跳转到目标图片的位置
      _scrollController.jumpTo(_getImageOffsetByIndex(newIndex));
    }
  }

  // 上一章节
  void _prevChapter() {
    if (chapterIndex <= 0) return;
    chapterIndex--;
    currentChapter = chapters[chapterIndex];
    _zoomController.value = Matrix4.identity();
    setState(() {
      _currentImageIndex = 0;
      _isCustomRangeSelecting = false;
      _customRangeStartOffset = null;
      _zoomGestureMode = false;
      _viewerInteracting = false;
      _activePointerCount = 0;
    });
    _listviewKey = UniqueKey();
    setState(() {
      images = currentChapter.images;
      imageCount = effectiveImageCount(currentChapter);
    });
    _scrollController.jumpTo(0.0);
    _calculateImageOffsets();
    cancelControlsTimer();
    init();
  }

  // 下一章节
  void _nextChapter() {
    if (chapterIndex >= chapters.length - 1) return;
    chapterIndex++;
    currentChapter = chapters[chapterIndex];
    _zoomController.value = Matrix4.identity();
    setState(() {
      _currentImageIndex = 0;
      _isCustomRangeSelecting = false;
      _customRangeStartOffset = null;
      _zoomGestureMode = false;
      _viewerInteracting = false;
      _activePointerCount = 0;
    });
    _listviewKey = UniqueKey();
    setState(() {
      images = currentChapter.images;
      imageCount = effectiveImageCount(currentChapter);
    });
    _scrollController.jumpTo(0.0);
    _calculateImageOffsets();
    cancelControlsTimer();
    init();
  }

  @override
  Widget build(BuildContext context) {
    AsyncValue<List<Map<String, dynamic>>> imagesAsync;
    if (images.isEmpty) {
      imagesAsync = ref.watch(
        onlineImagesWithChapterIdProvider(chapterId: currentChapter.id),
      );
    } else {
      imagesAsync = AsyncValue.data(images);
    }

    // 计算当前 Slider 的值
    double slideVal = sliderValue(_currentImageIndex, imageCount);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: handleTapToggle,
        child: Stack(
          children: [
            // 漫画阅读区域（下拉式 + 整体缩放）
            AsyncValueWidget(
              asyncValue: imagesAsync,
              dataBuilder: (data) {
                images = data;
                // 计算图片高度和偏移量
                _calculateImageOffsets();
                return _buildScrollGallery(context);
              },
            ),

            // 顶部控制栏
            if (showControls)
              TopControllBar(
                comicName: widget.comicInfo.comicName,
                chapterName: currentChapter.dirName,
                currentNum: _currentImageIndex,
                totalNum: imageCount,
                saveFunc: _onPrimarySavePressed,
                primaryIcon: _isCustomRangeSelecting
                    ? Icons.close_rounded
                    : Icons.save_alt_rounded,
                primaryIconColor: _isCustomRangeSelecting
                    ? Colors.redAccent.shade100
                    : Colors.white,
                primaryTooltip: _isCustomRangeSelecting
                    ? '取消自定义保存'
                    : '保存当前可见内容',
                secondarySaveFunc: _onSecondarySavePressed,
                secondaryIcon: Icons.crop_rounded,
                secondaryTooltip: _isCustomRangeSelecting
                    ? '完成自定义保存'
                    : '自定义起止保存',
                isMerging: _isMerging,
              ),

            // 底部控制栏
            if (showControls)
              BottomControllBar(
                prevFunc: _prevChapter,
                nextFunc: _nextChapter,
                slideVal: slideVal,
                onSlideFunc: _onSlideFunc,
                onSlideStart: () {
                  cancelControlsTimer();
                  if (!showControls) {
                    setState(() {
                      showControls = true;
                    });
                  }
                },
                onSlideEnd: () {
                  resetControlsTimer();
                },
              ),
          ],
        ),
      ),
    );
  }

  // 漫画内容部分构建
  Widget _buildScrollGallery(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width;
    final headers = ref.read(apiClientManagerProvider).headers;

    if (images.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUpOrCancel,
      onPointerCancel: _onPointerUpOrCancel,
      child: InteractiveViewer(
        transformationController: _zoomController,
        panEnabled: _enableViewerPan,
        panAxis: PanAxis.horizontal,
        scaleEnabled: true,
        minScale: 1.0,
        maxScale: 4.0,
        clipBehavior: Clip.hardEdge,
        boundaryMargin: EdgeInsets.zero,
        alignment: Alignment.topLeft,
        onInteractionStart: _onViewerInteractionStart,
        onInteractionUpdate: _onViewerInteractionUpdate,
        onInteractionEnd: _onViewerInteractionEnd,
        child: ListView.builder(
          key: _listviewKey,
          controller: _scrollController,
          physics: _shouldLockListScroll
              ? const NeverScrollableScrollPhysics()
              : const BouncingScrollPhysics(),
          itemCount: images.length,
          itemBuilder: (context, index) {
            final image = images[index];
            final url = resolveImageUrl(image, widget.isLocal, ref);
            // 抽离后的通用高度计算
            final height = computeImageHeight(image, maxWidth);
            return SizedBox(
              width: maxWidth,
              height: height,
              child: ComicImage(
                path: url,
                isLocal: widget.isLocal,
                httpHeaders: headers,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CropSegment {
  final int imageIndex;
  final double displayTop;
  final double displayBottom;

  const _CropSegment({
    required this.imageIndex,
    required this.displayTop,
    required this.displayBottom,
  });
}
