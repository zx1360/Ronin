import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/comic/models/chapter_info.dart';
import 'package:torrid/features/others/comic/models/comic_info.dart';
import 'package:torrid/features/others/comic/provider/status_provider.dart';
import 'package:torrid/features/others/comic/widgets/comic_browse/comic_image.dart';
import 'package:torrid/features/others/comic/widgets/comic_browse/top_bar.dart';

// TODO: 有奇怪的表现: 滑动时某些情况下会一下子往顶上滚到最开始.
class ComicScrollPage extends ConsumerStatefulWidget {
  final ComicInfo comicInfo;
  final int chapterIndex;

  const ComicScrollPage({
    super.key,
    required this.comicInfo,
    required this.chapterIndex,
  });

  @override
  ConsumerState<ComicScrollPage> createState() => _ComicScrollPageState();
}

class _ComicScrollPageState extends ConsumerState<ComicScrollPage> {
  // comic信息相关
  late int chapterIndex = widget.chapterIndex;
  List<ChapterInfo> chapterInfos = [];
  ChapterInfo? currentChapter;
  List<Map<String, dynamic>> images = [];

  // 状态量
  int _currentImageIndex = 0;
  bool _showControls = true;

  // 实现交互界面
  final ScrollController _scrollController = ScrollController();
  final Map<int, double> _imageOffsets = {};
  final Map<int, double> _imageHeights = {};
  late Timer _controlsTimer;
  bool _isDraggingSlider = false;
  final Duration closeBarDuration = const Duration(seconds: 4);

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
        print(images.length);
      });
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controlsTimer.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void init() {
    _initializeControlsTimer();
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

  void _prevChapter() {
    if (chapterIndex > 0) {
      setState(() {
        chapterIndex--;
        currentChapter = chapterInfos[chapterIndex];
        _currentImageIndex = 0;

        _controlsTimer.cancel();
        init();
        _scrollController.jumpTo(0);
      });
    }
  }

  void _nextChapter() {
    if (chapterIndex < chapterInfos.length - 1) {
      setState(() {
        chapterIndex++;
        currentChapter = chapterInfos[chapterIndex];
        _currentImageIndex = 0;

        _controlsTimer.cancel();
        init();
        _scrollController.jumpTo(0);
      });
    }
  }

  void _onScroll() {
    if (_isDraggingSlider || images.isEmpty) return;

    _updateCurrentImageIndex();
  }

  // 在滑动时更新当前img页数.
  void _updateCurrentImageIndex() {
    if (_imageOffsets.isEmpty ||
        _scrollController.position.maxScrollExtent == 0) {
      return;
    }

    final currentPosition = _scrollController.position.pixels;
    double cumulativeOffset = 0.0;

    for (int i = 0; i < images.length; i++) {
      final imageHeight = _imageHeights[i] ?? 0.0;

      // 计算图片可见比例
      final visibleStart = currentPosition;
      final visibleEnd =
          currentPosition + _scrollController.position.viewportDimension;

      final overlapStart = max(cumulativeOffset, visibleStart);
      final overlapEnd = min(cumulativeOffset + imageHeight, visibleEnd);
      final visibleRatio = (overlapEnd - overlapStart) / imageHeight;

      // 当图片可见比例超过50%时，认为是当前阅读的图片
      if (visibleRatio > 0.5) {
        if (_currentImageIndex != i) {
          setState(() {
            _currentImageIndex = i;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              // ref
              //     .read(comicPreferenceProvider.notifier)
              //     .updateProgress(
              //       comicName: widget.comicName,
              //       chapterIndex: chapterIndex,
              //       pageIndex: i,
              //     );
            }
          });
        }
        break;
      }

      cumulativeOffset += imageHeight;
    }
  }

  void _jumpToImage(int index) {
    if (index < 0 || index >= images.length || _imageOffsets.isEmpty) {
      return;
    }

    setState(() {
      _currentImageIndex = index;
      _isDraggingSlider = true;
    });

    _scrollController
        .animateTo(
          _imageOffsets[index] ?? 0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        )
        .whenComplete(() {
          setState(() {
            _isDraggingSlider = false;
          });
        });
  }

  @override
  Widget build(BuildContext context) {
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
            _buildScrollGallery(),

            // 顶部控制栏
            if (_showControls)
              TopBar(
                comicName: widget.comicInfo.comicName,
                chapterName: currentChapter?.dirName ?? "",
                currentNum: _currentImageIndex,
                totalNum: images.length,
              ),

            // 底部控制栏
            if (_showControls && images.length > 1)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom,
                    left: 12,
                    right: 12,
                    top: 16,
                  ),
                  color: Colors.black54,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.skip_previous,
                          color: Colors.white,
                        ),
                        onPressed: _prevChapter,
                        disabledColor: Colors.grey,
                      ),
                      Expanded(
                        child: Slider(
                          value: _currentImageIndex.toDouble(),
                          min: 0,
                          max: (images.length - 1).toDouble(),
                          divisions: images.length - 1,
                          activeColor: Colors.white,
                          inactiveColor: Colors.white38,
                          onChanged: (value) {
                            setState(() {
                              _currentImageIndex = value.round();
                            });
                            _resetControlsTimer();
                          },
                          onChangeStart: (value) {
                            setState(() {
                              _isDraggingSlider = true;
                            });
                          },
                          onChangeEnd: (value) {
                            _jumpToImage(value.round());
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next, color: Colors.white),
                        onPressed: _nextChapter,
                        disabledColor: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),
            if (_showControls && images.length == 1)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom,
                    top: 16,
                  ),
                  color: Colors.black54,
                  child: const Center(
                    child: Text('1/1', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 漫画内容部分构建
  Widget _buildScrollGallery() {
    if (images.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      itemCount: images.length,
      itemBuilder: (context, index) {
        return ComicImage(path: images[index]['path']);
      },
    );
  }

  // 更新所有图片位置信息
  void _updateImagePositions() {
    double offset = 0.0;
    double totalHeight = 0.0;

    // 先计算所有图片高度总和
    for (int i = 0; i < images.length; i++) {
      totalHeight += _imageHeights[i] ?? 0.0;
    }

    // 检查是否需要调整滚动位置
    final currentPosition = _scrollController.position.pixels;
    final viewportHeight = _scrollController.position.viewportDimension;
    final maxScrollExtent = totalHeight - viewportHeight;

    if (currentPosition > maxScrollExtent && maxScrollExtent > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(maxScrollExtent);
        }
      });
    }

    // 重新计算偏移量
    offset = 0.0;
    for (int i = 0; i < images.length; i++) {
      _imageOffsets[i] = offset;
      offset += _imageHeights[i] ?? 0.0;
    }

    _updateCurrentImageIndex();
  }
}
