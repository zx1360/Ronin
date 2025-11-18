import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:torrid/features/others/comic/models/chapter_info.dart';
import 'package:torrid/features/others/comic/models/comic_info.dart';
import 'package:torrid/features/others/comic/provider/notifier_provider.dart';
import 'package:torrid/features/others/comic/provider/status_provider.dart';
import 'package:torrid/features/others/comic/widgets/comic_browse/bottom_bar.dart';
import 'package:torrid/features/others/comic/widgets/comic_browse/top_bar.dart';
import 'package:torrid/services/debug/logging_service.dart';
import 'package:torrid/services/io/io_service.dart';

class ComicReadPage extends ConsumerStatefulWidget {
  final ComicInfo comicInfo;
  final int chapterIndex;

  const ComicReadPage({
    super.key,
    required this.comicInfo,
    required this.chapterIndex,
  });

  @override
  ConsumerState<ComicReadPage> createState() => _ComicReadPageState();
}

class _ComicReadPageState extends ConsumerState<ComicReadPage> {
  late List<ChapterInfo> chapterInfos;
  late int chapterIndex = widget.chapterIndex;
  ChapterInfo? currentChapter;
  List<Map<String, dynamic>> images = [];
  // 是否展示操作栏
  bool _showControls = true;
  // 图片加载相关
  int _currentImageIndex = 0;
  late PageController _pageController;
  // 自动关闭操作栏计时器
  late Timer _controlsTimer;
  final Duration closeBarDuration = const Duration(seconds: 4);
  final Duration switchImgDuration = const Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    init();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      chapterInfos = ref.read(
        chaptersWithComicIdProvider(comicId: widget.comicInfo.id),
      );
      currentChapter = chapterInfos[chapterIndex];
      setState(() {
        images = currentChapter!.images;
      });
    });
    _pageController = PageController(initialPage: _currentImageIndex);
  }

  void init() {
    ref
        .read(comicServiceProvider.notifier)
        .modifyComicPref(
          comicId: widget.comicInfo.id,
          chapterIndex: chapterIndex,
        );
    _initializeControlsTimer();
  }

  @override
  void dispose() {
    _controlsTimer.cancel();
    // 退出时恢复系统UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _initializeControlsTimer() {
    _controlsTimer = Timer.periodic(closeBarDuration, (timer) {
      if (mounted && _showControls) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _resetControlsTimer() {
    _controlsTimer.cancel();
    setState(() {
      _showControls = true;
    });
    _initializeControlsTimer();
  }

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
      currentChapter = chapterInfos[chapterIndex];
      _currentImageIndex = 0;
      setState(() {
        images = currentChapter!.images;
      });
      _controlsTimer.cancel();
      init();
      _pageController.jumpToPage(0);
    }
  }

  // 下一章节
  void _nextChapter() {
    if (chapterIndex < chapterInfos.length - 1) {
      chapterIndex++;
      currentChapter = chapterInfos[chapterIndex];
      _currentImageIndex = 0;
      setState(() {
        images = currentChapter!.images;
      });
      _controlsTimer.cancel();
      init();
      _pageController.jumpToPage(0);
    }
  }

  // TODO: 提取, 分离.
  Future<void> _saveThisImage(BuildContext context) async {
    try {
      // 获取当前图片文件
      final sourceFile = File(images[_currentImageIndex]['path']);
      if (!await sourceFile.exists()) {
        _showSnackBar(context, "图片文件不存在");
        return;
      }

      // 生成保存的文件名（漫画名_章节号_页码.扩展名）
      final fileExtension = sourceFile.path.split('.').last;
      final fileName =
          "${widget.comicInfo.comicName}_"
          "第${currentChapter!.chapterIndex}章_"
          "第${_currentImageIndex + 1}页."
          "$fileExtension";
      IoService.saveImageToPublic(images[_currentImageIndex]['path'], fileName);

      _showSnackBar(context, "图片已保存: $fileName");
    } catch (e) {
      _showSnackBar(context, "保存失败: ${e.toString()}");
      AppLogger().error("保存图片错误: $e");
    }
  }

  // 显示提示信息
  void _showSnackBar(BuildContext context, String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          if (_showControls) {
            _controlsTimer.cancel();
            setState(() {
              _showControls = false;
            });
          } else {
            _resetControlsTimer();
          }
        },
        child: Stack(
          children: [
            // 漫画阅读区域
            _buildGallery(),

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
            if (_showControls)
              TopControllBar(
                comicName: widget.comicInfo.comicName,
                chapterName: currentChapter?.dirName??"",
                currentNum: _currentImageIndex,
                totalNum: currentChapter?.images.length??1,
                saveFunc: () {
                  _saveThisImage(context);
                },
              ),

            // 底部控制栏 - 只有当图片数量大于1时才显示进度条和翻页按钮
            if (_showControls)
              BottomControllBar(
                prevFunc: _prevChapter,
                nextFunc: _nextChapter,
                slideVal: _getSliderValue(),
                onSlideFunc: (value) {
                  if (currentChapter!.images.isNotEmpty) {
                    _pageController.jumpToPage(
                      (value * (images.length - 1)).round(),
                    );
                  }
                  _resetControlsTimer();
                },
              ),
          ],
        ),
      ),
    );
  }

  // 获取滑块进度条.
  double _getSliderValue() {
    if (images.length <= 1) {
      return -1;
    }
    return _currentImageIndex / (images.length - 1);
  }

  Widget _buildGallery() {
    if (images.isEmpty) {
      return const Center(child: Text('该章节没有找到图片'));
    }

    // TODO: 图片预加载前后一张图片防止短暂空白.
    return PhotoViewGallery.builder(
      itemCount: images.length,
      builder: (context, index) {
        return PhotoViewGalleryPageOptions(
          imageProvider: FileImage(File(images[index]['path'])),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 2,
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
