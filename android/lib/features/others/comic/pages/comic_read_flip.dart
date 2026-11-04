import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
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
import 'package:torrid/providers/api_client/api_client_provider.dart';

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
  late final List<ChapterInfo> chapters = widget.chapters;
  late int chapterIndex = widget.chapterIndex;
  ChapterInfo get currentChapter => chapters[chapterIndex];
  late List<Map<String, dynamic>> images = currentChapter.images;
  late int imageCount = effectiveImageCount(currentChapter);
  int _currentImageIndex = 0;
  final PageController _pageController = PageController();
  bool _isSaving = false;
  final Duration switchImgDuration = const Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _recordChapter();
  }

  void _recordChapter() {
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
    _pageController.dispose();
    // 退出时恢复系统UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

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

  void _prevChapter() => _changeChapter(chapterIndex - 1);
  void _nextChapter() => _changeChapter(chapterIndex + 1);

  void _changeChapter(int index) {
    if (index < 0 || index >= chapters.length) return;
    setState(() {
      chapterIndex = index;
      _currentImageIndex = 0;
      images = currentChapter.images;
      imageCount = effectiveImageCount(currentChapter);
    });
    _recordChapter();
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        0,
        duration: switchImgDuration,
        curve: Curves.easeInOut,
      );
    }
  }

  Future<List<int>> _fetchOnlineImageBytes(String imagePath) async {
    final normalizedPath = imagePath.startsWith('/')
        ? imagePath.substring(1)
        : imagePath;
    final response = await ref
        .read(apiClientManagerProvider)
        .getBinary('/static/$normalizedPath');
    if (response.statusCode != 200 || response.data == null) {
      throw Exception('在线图片下载失败');
    }
    return response.data!;
  }

  // 保存图片.
  Future<void> _saveThisImage() async {
    if (_isSaving || images.isEmpty) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final imagePath = images[_currentImageIndex]['path']?.toString() ?? '';
      if (imagePath.isEmpty) {
        throw Exception('图片路径为空');
      }

      final extName = path.extension(imagePath).replaceFirst('.', '');
      final safeExt = extName.isEmpty ? 'png' : extName;

      // 生成保存的文件名（漫画名_章节号_页码.扩展名）
      final fileName =
          "${widget.comicInfo.comicName}_"
          "第${currentChapter.chapterIndex}章_"
          "第${_currentImageIndex + 1}页."
          "$safeExt";

      bool saved;
      if (widget.isLocal) {
        final sourceFile = File(imagePath);
        if (!await sourceFile.exists()) {
          throw Exception('图片文件不存在');
        }
        saved = await ComicSaverService.saveFlipImageToPublic(
          sourceFile.path,
          fileName,
        );
      } else {
        final bytes = await _fetchOnlineImageBytes(imagePath);
        saved = await ComicSaverService.saveImageBytesToPublic(bytes, fileName);
      }

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
      AppLogger().error("保存图片错误: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
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
                totalNum: imageCount,
                saveFunc: () => _saveThisImage(),
                isMerging: _isSaving,
              ),

            // 底部控制栏 - 只有当图片数量大于1时才显示进度条和翻页按钮
            if (showControls)
              BottomControllBar(
                prevFunc: _prevChapter,
                nextFunc: _nextChapter,
                slideVal: sliderValue(_currentImageIndex, imageCount),
                onSlideFunc: (value) {
                  if (images.isNotEmpty) {
                    _pageController.jumpToPage(
                      (value * (images.length - 1)).round(),
                    );
                  }
                },
                onSlideStart: cancelControlsTimer,
                onSlideEnd: resetControlsTimer,
              ),
          ],
        ),
      ),
    );
  }

  /// 预加载相邻图片（前后各1张）
  void _precacheAdjacentImages(int currentIndex) {
    final indicesToPrecache = [currentIndex - 1, currentIndex + 1];
    for (final i in indicesToPrecache) {
      if (i >= 0 && i < images.length) {
        final imageProvider = resolveImageProvider(
          images[i],
          widget.isLocal,
          ref,
        );
        precacheImage(imageProvider, context);
      }
    }
  }

  Widget _buildGallery() {
    if (images.isEmpty) {
      return const Center(child: Text('该章节没有找到图片'));
    }

    return PhotoViewGallery.builder(
      key: ValueKey(
        'comic_gallery_${currentChapter.id}_${currentChapter.chapterIndex}',
      ),
      itemCount: images.length,
      builder: (context, index) {
        final ImageProvider imageProvider = resolveImageProvider(
          images[index],
          widget.isLocal,
          ref,
        );
        return PhotoViewGalleryPageOptions(
          imageProvider: imageProvider,
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 2,
          tightMode: true,
        );
      },
      scrollPhysics: const ClampingScrollPhysics(),
      backgroundDecoration: const BoxDecoration(color: Colors.black),

      onPageChanged: (index) {
        setState(() {
          _currentImageIndex = index;
        });
        // 预加载前后图片
        _precacheAdjacentImages(index);
      },
      pageController: _pageController,
    );
  }
}
