import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  // 实现交互界面
  final ScrollController _scrollController = ScrollController();

  /// 用于存储每一张图片在列表中的累计高度，方便快速计算滚动位置
  final List<double> _imageOffsets = [];

  @override
  void initState() {
    super.initState();
    init();
    // 初始化滚动监听器
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    disposeControlsTimer();
    _scrollController.removeListener(_onScroll); // 移除监听器
    _scrollController.dispose();
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

  // 图片保存(连带上下的完整保存)
  Future<void> _saveImage() async {
    try {
      final screenHeight = MediaQuery.of(context).size.height;
      final visibleTop = _scrollController.offset;
      final visibleBottom = visibleTop + screenHeight;
      int startIndex =
          _imageOffsets.indexWhere((offset) => offset > visibleTop) - 1;
      int endIndex =
          _imageOffsets.indexWhere((offset) => offset >= visibleBottom) - 1;
      startIndex = startIndex >= 0 ? startIndex : 0;
      endIndex = endIndex < 0 ? images.length - 1 : endIndex;

      final imagePaths = <String>[];
      for (int i = startIndex; i <= endIndex; i++) {
        imagePaths.add(images[i]['path']);
      }
      final filename =
          "${widget.comicInfo.comicName}_第${currentChapter.chapterIndex}章_${startIndex + 1}-${endIndex + 1}";
      setState(() {
        _isMerging = true;
      });
      await ComicSaverService.saveScrollImagesToPublic(imagePaths, filename);
      if (!mounted) return;
      displaySnackBar(context, "图片已保存: $filename");
    } catch (e) {
      if (mounted) {
        displaySnackBar(context, "保存失败: ${e.toString()}");
      }
      AppLogger().error("保存图片错误: $e");
    } finally {
      setState(() {
        _isMerging = false;
      });
    }
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
    setState(() {
      _currentImageIndex = 0;
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
    setState(() {
      _currentImageIndex = 0;
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
                saveFunc: widget.isLocal ? () => _saveImage() : null,
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
    return ListView.builder(
      key: _listviewKey,
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      itemCount: images.length,
      itemBuilder: (context, index) {
        final image = images[index];
        final url = resolveImageUrl(image, widget.isLocal, ref);
        // 抽离后的通用高度计算
        final height = computeImageHeight(image, maxWidth);
        return SizedBox(
          width: maxWidth,
          height: height,
          child: ComicImage(path: url, isLocal: widget.isLocal, httpHeaders: headers),
        );
      },
    );
  }
}
