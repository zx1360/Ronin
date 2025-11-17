import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/comic/models/chapter_info.dart';
import 'package:torrid/features/others/comic/services/io_image_service.dart';
import 'package:torrid/features/others/comic/widgets/comic_browse/comic_image.dart';
import 'package:torrid/features/others/comic/widgets/comic_browse/top_bar.dart';

// TODO: 有奇怪的表现: 滑动时某些情况下会一下子往顶上滚到最开始.
class ComicScrollPage extends ConsumerStatefulWidget {
  final List<ChapterInfo> chapters;
  final int currentChapter;
  final String comicName;

  const ComicScrollPage({
    super.key,
    required this.chapters,
    required this.currentChapter,
    required this.comicName,
  });

  @override
  ConsumerState<ComicScrollPage> createState() => _ComicScrollPageState();
}

class _ComicScrollPageState extends ConsumerState<ComicScrollPage> {
  // comic信息相关
  late int _currentChapter = widget.currentChapter;
  late ChapterInfo _chapterInfo = widget.chapters[_currentChapter];
  List<String> _imagePaths = [];

  // 状态量
  int _currentImageIndex = 0;
  bool _showControls = true;
  bool _isLoading = true;

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
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controlsTimer.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void init() {
    _loadChapterImages();
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

  // 加载所有图片并获取其长宽用作获取当前阅读页数.
  Future<void> _loadChapterImages() async {
    try {
      final paths = await loadChapterImages(_chapterInfo.dirName);
      setState(() {
        _imagePaths = paths;
        _isLoading = false;
        _imageOffsets.clear();
        _imageHeights.clear();
      });
      // 预计算所有图片尺寸
      for (int i = 0; i < _imagePaths.length; i++) {
        final size = await getImageSize(_imagePaths[i]);
        final screenWidth = MediaQuery.of(context).size.width;
        final imageHeight = (screenWidth / size.width) * size.height;

        _imageHeights[i] = imageHeight;
      }
      setState(() {});

      _updateImagePositions();
    } catch (e) {
      // 报错.
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('加载图片失败: ${e.toString()}')));
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _prevChapter() {
    if (_currentChapter > 0) {
      setState(() {
        _currentChapter--;
        _chapterInfo = widget.chapters[_currentChapter];
        _currentImageIndex = 0;
        _isLoading = true;

        _controlsTimer.cancel();
        init();
        _scrollController.jumpTo(0);
      });
    }
  }

  void _nextChapter() {
    if (_currentChapter < widget.chapters.length - 1) {
      setState(() {
        _currentChapter++;
        _chapterInfo = widget.chapters[_currentChapter];
        _currentImageIndex = 0;
        _isLoading = true;

        _controlsTimer.cancel();
        init();
        _scrollController.jumpTo(0);
      });
    }
  }

  void _onScroll() {
    if (_isDraggingSlider || _imagePaths.isEmpty) return;

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

    for (int i = 0; i < _imagePaths.length; i++) {
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
              //       chapterIndex: _currentChapter,
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
    if (index < 0 || index >= _imagePaths.length || _imageOffsets.isEmpty) {
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
                comicName: widget.comicName,
                chapterName: _chapterInfo.dirName,
                currentNum: _currentImageIndex,
                totalNum: _imagePaths.length,
              ),

            // 底部控制栏
            if (_showControls && _imagePaths.length > 1)
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
                          max: (_imagePaths.length - 1).toDouble(),
                          divisions: _imagePaths.length - 1,
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
            if (_showControls && _imagePaths.length == 1)
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
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_imagePaths.isEmpty) {
      return const Center(
        child: Text(
          '该章节没有找到图片',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      itemCount: _imagePaths.length,
      itemBuilder: (context, index) {
        return ComicImage(path: _imagePaths[index]);
      },
    );
  }

  // 更新所有图片位置信息
  void _updateImagePositions() {
    double offset = 0.0;
    double totalHeight = 0.0;

    // 先计算所有图片高度总和
    for (int i = 0; i < _imagePaths.length; i++) {
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
    for (int i = 0; i < _imagePaths.length; i++) {
      _imageOffsets[i] = offset;
      offset += _imageHeights[i] ?? 0.0;
    }

    _updateCurrentImageIndex();
  }
}
