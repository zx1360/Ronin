import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:torrid/core/widgets/async_value_widget/async_value_widget.dart';

import 'package:torrid/features/others/comic/models/chapter_info.dart';
import 'package:torrid/features/others/comic/models/comic_info.dart';
import 'package:torrid/features/others/comic/provider/notifier_provider.dart';
import 'package:torrid/features/others/comic/provider/online_status_provider.dart';
import 'package:torrid/features/others/comic/services/save_service.dart';
import 'package:torrid/features/others/comic/widgets/comic_browse/bottom_bar.dart';
import 'package:torrid/features/others/comic/widgets/comic_browse/top_bar.dart';
import 'package:torrid/core/services/debug/logging_service.dart';
import 'package:torrid/core/modals/snack_bar.dart';
import 'package:torrid/features/others/comic/common/controls_auto_hide_mixin.dart';
import 'package:torrid/features/others/comic/common/reader_utils.dart';

class ComicReadPage extends ConsumerStatefulWidget {
  final ComicInfo comicInfo;
  final List<ChapterInfo> chapters;
  final int chapterIndex;
  final bool isLocal;

  const ComicReadPage({
    super.key,
    required this.comicInfo,
    required this.chapters,
    required this.chapterIndex,
    required this.isLocal,
  });

  @override
  ConsumerState<ComicReadPage> createState() => _ComicReadPageState();
}

class _ComicReadPageState extends ConsumerState<ComicReadPage>
    with ControlsAutoHideMixin<ComicReadPage> {
  late List<ChapterInfo> chapters = widget.chapters;
  late int chapterIndex = widget.chapterIndex;
  late ChapterInfo currentChapter = chapters[chapterIndex];
  late List<Map<String, dynamic>> images = currentChapter.images;
  late int imageCount = effectiveImageCount(currentChapter);
  // 是否展示操作栏
  // 图片加载相关
  int _currentImageIndex = 0;
  late PageController _pageController;
  // 自动关闭操作栏计时器
  final Duration switchImgDuration = const Duration(milliseconds: 300);
  

  @override
  void initState() {
    super.initState();
    init();
    _pageController = PageController(initialPage: _currentImageIndex);
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

  @override
  void dispose() {
    disposeControlsTimer();
    // 退出时恢复系统UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // 计时器逻辑由 ControlsAutoHideMixin 提供

  // 导航到上一页
  void _prevImage() {
    if (_currentImageIndex > 0) {
      _pageController.previousPage(
        duration: switchImgDuration,
        curve: Curves.easeInOut,
      );
    } else {
      _prevChapter();
    }
  }

  // 导航到下一页
  void _nextImage() {
    if (_currentImageIndex < images.length - 1) {
      _pageController.nextPage(
        duration: switchImgDuration,
        curve: Curves.easeInOut,
      );
    } else {
      _nextChapter();
    }
  }

  // 上一章节
  void _prevChapter() {
    if (chapterIndex > 0) {
      chapterIndex--;
      currentChapter = chapters[chapterIndex];
      _currentImageIndex = 0;
      setState(() {
        images = currentChapter.images;
        imageCount = effectiveImageCount(currentChapter);
      });
      cancelControlsTimer();
      init();
      _pageController.animateToPage(0, duration: switchImgDuration, curve: Curves.easeInOut);
    }
  }

  // 下一章节
  void _nextChapter() {
    if (chapterIndex < chapters.length - 1) {
      chapterIndex++;
      currentChapter = chapters[chapterIndex];
      _currentImageIndex = 0;
      setState(() {
        images = currentChapter.images;
        imageCount = effectiveImageCount(currentChapter);
      });
      cancelControlsTimer();
      init();
      _pageController.animateToPage(0, duration: switchImgDuration, curve: Curves.easeInOut);
    }
  }

  // 保存图片.
  Future<void> _saveThisImage(BuildContext context) async {
    try {
      // 获取当前图片文件
      final sourceFile = File(images[_currentImageIndex]['path']);
      if (!await sourceFile.exists()) {
        if (mounted) {
          displaySnackBar(context, "图片文件不存在");
        }
        return;
      }

      // 生成保存的文件名（漫画名_章节号_页码.扩展名）
      final fileExtension = sourceFile.path.split('.').last;
      final fileName =
          "${widget.comicInfo.comicName}_"
          "第${currentChapter.chapterIndex}章_"
          "第${_currentImageIndex + 1}页."
          "$fileExtension";
      ComicSaverService.saveFlipImageToPublic(
        images[_currentImageIndex]['path'],
        fileName,
      );
      if (mounted) {
        displaySnackBar(context, "图片已保存: $fileName");
      }
    } catch (e) {
      if (mounted) {
        displaySnackBar(context, "保存失败: ${e.toString()}");
      }
      AppLogger().error("保存图片错误: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // 图片信息的获取(兼容在线阅读)
    AsyncValue<List<Map<String, dynamic>>> imagesAsync;
    if (images.isEmpty) {
      imagesAsync = ref.watch(
        onlineImagesWithChapterIdProvider(chapterId: currentChapter.id),
      );
    } else {
      imagesAsync = AsyncValue.data(images);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: handleTapToggle,
        child: Stack(
          children: [
            // 漫画阅读区域
            AsyncValueWidget(
              asyncValue: imagesAsync,
              dataBuilder: (data) {
                images = data;
                return _buildGallery();
              },
            ),

            // 点击翻页区
            ...[
              Positioned(
                top: 0,
                bottom: 0,
                left: 0,
                width: MediaQuery.of(context).size.width / 4,
                child: GestureDetector(
                  onTap: _prevImage,
                  behavior: HitTestBehavior.translucent,
                ),
              ),
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                width: MediaQuery.of(context).size.width / 4,
                child: GestureDetector(
                  onTap: _nextImage,
                  behavior: HitTestBehavior.translucent,
                ),
              ),
            ],

            // 顶部控制栏
            if (showControls)
              TopControllBar(
                comicName: widget.comicInfo.comicName,
                chapterName: currentChapter.dirName,
                currentNum: _currentImageIndex,
                totalNum:
                    imageCount,
                saveFunc: widget.isLocal ? () => _saveThisImage(context) : null,
              ),

            // 底部控制栏 - 只有当图片数量大于1时才显示进度条和翻页按钮
            if (showControls)
              BottomControllBar(
                prevFunc: _prevChapter,
                nextFunc: _nextChapter,
                slideVal: _getSliderValue(),
                onSlideFunc: (value) {
                  if (images.isNotEmpty) {
                    _pageController.jumpToPage(
                      (value * (images.length - 1)).round(),
                    );
                  }
                },
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

  // 获取滑块进度条.
  double _getSliderValue() {
    return sliderValue(_currentImageIndex, imageCount);
  }

  Widget _buildGallery() {
    if (images.isEmpty) {
      return const Center(child: Text('该章节没有找到图片'));
    }

    // TODO: 图片预加载前后一张图片防止短暂空白.
    return PhotoViewGallery.builder(
      key: ValueKey('comic_gallery_${currentChapter.id}_${currentChapter.chapterIndex}'),
      itemCount: images.length,
      builder: (context, index) {
        final ImageProvider imageProvider =
            resolveImageProvider(images[index], widget.isLocal, ref);
        return PhotoViewGalleryPageOptions(
          imageProvider: imageProvider,
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 2,
          tightMode: true
        );
      },
      scrollPhysics: const ClampingScrollPhysics(),
      backgroundDecoration: const BoxDecoration(color: Colors.black),

      onPageChanged: (index) {
        setState(() {
          _currentImageIndex = index;
        });
      },
      pageController: _pageController,
    );
  }
}
