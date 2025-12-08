import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:torrid/features/others/comic/models/chapter_info.dart';
import 'package:torrid/features/others/comic/models/comic_info.dart';

import 'package:torrid/features/others/comic/provider/notifier_provider.dart';
import 'package:torrid/features/others/comic/provider/online_status_provider.dart';

import 'package:torrid/features/others/comic/services/save_service.dart';

import 'package:torrid/features/others/comic/widgets/comic_browse/bottom_bar.dart';
import 'package:torrid/features/others/comic/widgets/comic_browse/comic_image.dart';
import 'package:torrid/features/others/comic/widgets/comic_browse/top_bar.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

import 'package:torrid/services/debug/logging_service.dart';
import 'package:torrid/shared/bottom/snack_bar.dart';

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

class _ComicScrollPageState extends ConsumerState<ComicScrollPage> {
  // 为了使ListView的跳转正常.  使用globalKey使每次刷新重新构建, 防止遗留信息阻止正常显示.
  Key _listviewKey = UniqueKey();
  // comic信息相关
  late List<ChapterInfo> chapters = widget.chapters;
  late int chapterIndex = widget.chapterIndex;
  late ChapterInfo currentChapter = chapters[chapterIndex];
  late List<Map<String, dynamic>> images = currentChapter.images;

  // 状态量
  int _currentImageIndex = 0;
  bool _showControls = true;
  bool _isMerging = false;

  // 实现交互界面
  final ScrollController _scrollController = ScrollController();
  late Timer _controlsTimer;
  final Duration closeBarDuration = const Duration(seconds: 4);

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
    _controlsTimer.cancel();
    _scrollController.removeListener(_onScroll); // 移除监听器
    _scrollController.dispose();
    super.dispose();
  }

  /// 计算所有图片的高度和累计偏移量
  void _calculateImageOffsets() {
    _imageOffsets.clear();
    double currentOffset = 0.0;
    final maxWidth = MediaQuery.of(context).size.width;
    for (var image in images) {
      _imageOffsets.add(currentOffset);
      final width = image['width'];
      final height = image['height'] * (maxWidth / width);
      currentOffset += height;
    }
    // 添加最后一张图片的底部位置，方便计算
    _imageOffsets.add(currentOffset);
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

  // 初始化计时器
  void _initializeControlsTimer() {
    _controlsTimer = Timer.periodic(closeBarDuration, (timer) {
      if (mounted && _showControls) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  // 重置计时器
  void _resetControlsTimer() {
    _controlsTimer.cancel();
    setState(() {
      _showControls = true;
    });
    _initializeControlsTimer();
  }

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
      showSnackBar(context, "图片已保存: $filename");
    } catch (e) {
      showSnackBar(context, "保存失败: ${e.toString()}");
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
    _currentImageIndex = 0;
    _listviewKey = UniqueKey();
    setState(() {
      images = currentChapter.images;
    });
    _scrollController.jumpTo(0.0);
    _calculateImageOffsets();
    _controlsTimer.cancel();
    init();
  }

  // 下一章节
  void _nextChapter() {
    if (chapterIndex >= chapters.length - 1) return;
    chapterIndex++;
    currentChapter = chapters[chapterIndex];
    _currentImageIndex = 0;
    _listviewKey = UniqueKey();
    setState(() {
      images = currentChapter.images;
    });
    _scrollController.jumpTo(0.0);
    _calculateImageOffsets();
    _controlsTimer.cancel();
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
    double slideVal = -1;

    return Scaffold(
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
            // 漫画阅读区域（下拉式 + 整体缩放）
            imagesAsync.when(
              data: (data) {
                images = data;
                if(images.length>1) {
                  slideVal = _currentImageIndex / (images.length - 1);
                }
                // 计算图片高度和偏移量
                _calculateImageOffsets();
                return _buildScrollGallery(context);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('错误：$error')),
            ),

            // 顶部控制栏
            if (_showControls)
              TopControllBar(
                comicName: widget.comicInfo.comicName,
                chapterName: currentChapter.dirName,
                currentNum: _currentImageIndex,
                totalNum: images.length,
                saveFunc: widget.isLocal? () => _saveImage() : null,
                isMerging: _isMerging,
              ),

            // 底部控制栏
            if (_showControls)
              BottomControllBar(
                prevFunc: _prevChapter,
                nextFunc: _nextChapter,
                slideVal: slideVal,
                onSlideFunc: _onSlideFunc,
                onSlideStart: () {
                  _controlsTimer.cancel();
                  if (!_showControls) {
                    setState(() {
                      _showControls = true;
                    });
                  }
                },
                onSlideEnd: () {
                  _resetControlsTimer();
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
        final url = widget.isLocal? images[index]['path']: "${ref.watch(apiClientManagerProvider).baseUrl}/static/${images[index]['path']}";
        
        final image = images[index];
        final width = image['width'];
        // 确保宽度不为0，避免除零错误
        final height = width > 0
            ? image['height'] * (maxWidth / width)
            : maxWidth;
        return SizedBox(
          width: maxWidth,
          height: height,
          child: ComicImage(path: url, isLocal: widget.isLocal,),
        );
      },
    );
  }
}
