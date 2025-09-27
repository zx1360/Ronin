// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'comic_detail.dart';


// TODO: 还有一些漏洞:
//    缩放体验不好, 很容易识别为漫画滚动, 
//    滑动阅读时, 比较容易识别为一下子往顶上滚到最开始.
class ComicScrollPage extends StatefulWidget {
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
  State<ComicScrollPage> createState() => _ComicScrollPageState();
}

class _ComicScrollPageState extends State<ComicScrollPage> {
  late int _currentChapter = widget.currentChapter;
  late ChapterInfo _chapterInfo = widget.chapters[_currentChapter];
  bool _showControls = true;
  bool _isLoading = true;
  List<String> _imagePaths = [];
  int _currentImageIndex = 0;
  final ScrollController _scrollController = ScrollController();
  final Map<int, double> _imageOffsets = {};
  final Map<int, double> _imageHeights = {};
  late Timer _controlsTimer;
  final Duration closeBarDuration = const Duration(seconds: 4);
  bool _isDraggingSlider = false;
  
  // 缩放相关控制器
  final TransformationController _transformationController = TransformationController();
  final double _minScale = 1.0;
  final double _maxScale = 3.0;

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
    _transformationController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
    _toggleSystemUi();
  }

  void _toggleSystemUi() {
    SystemChrome.setEnabledSystemUIMode(
      _showControls ? SystemUiMode.edgeToEdge : SystemUiMode.immersive,
    );
  }

  Future<void> _loadChapterImages() async {
    try {
      final chapterDir = Directory(_chapterInfo.path);

      final imageFiles = await chapterDir
          .list()
          .where(
            (entity) =>
                entity is File &&
                [
                  'jpg',
                  'jpeg',
                  'png',
                  'gif',
                ].contains((entity).path.split('.').last.toLowerCase()),
          )
          .toList();

      imageFiles.sort((a, b) {
        final aName = (a as File).path
            .split(Platform.pathSeparator)
            .last
            .split('.')
            .first;
        final bName = (b as File).path
            .split(Platform.pathSeparator)
            .last
            .split('.')
            .first;
        return int.tryParse(aName)?.compareTo(int.tryParse(bName) ?? 0) ?? 0;
      });

      setState(() {
        _imagePaths = imageFiles.map((file) => (file as File).path).toList();
        _isLoading = false;
        _imageOffsets.clear();
        _imageHeights.clear();
        for (int i = 0; i < _imagePaths.length; i++) {
          _imageOffsets[i] = 0.0;
          _imageHeights[i] = 0.0;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载图片失败: ${e.toString()}'))
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _prevChapter() {
    if (_currentChapter > 0) {
      _resetZoom();
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
      _resetZoom();
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

    setState(() {
      _updateCurrentImageIndex();
    });
  }

  void _updateCurrentImageIndex() {
    if (_imageOffsets.isEmpty || _scrollController.position.maxScrollExtent == 0) {
      return;
    }

    final currentPosition = _scrollController.position.pixels;
    for (int i = _imagePaths.length - 1; i >= 0; i--) {
      final imageOffset = _imageOffsets[i] ?? 0.0;
      final imageHeight = _imageHeights[i] ?? 0.0;
      if (currentPosition >= imageOffset - 100 || 
          (currentPosition >= imageOffset && currentPosition <= imageOffset + imageHeight)) {
        setState(() {
          _currentImageIndex = i;
        });
        break;
      }
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

    _scrollController.animateTo(
      _imageOffsets[index] ?? 0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    ).whenComplete(() {
      setState(() {
        _isDraggingSlider = false;
      });
    });
  }

  // 重置缩放
  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  // 处理缩放范围限制
  void _handleScale() {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    
    // 限制缩放范围
    if (currentScale < _minScale) {
      _transformationController.value = Matrix4.identity()..scale(_minScale);
    } else if (currentScale > _maxScale) {
      _transformationController.value = Matrix4.identity()..scale(_maxScale);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () {
          if(_showControls){
            _controlsTimer.cancel();
            setState(() {
              _showControls = false;
            });
          }else{
            _resetControlsTimer();
          }
        },
        child: Stack(
          children: [
            // 漫画阅读区域（下拉式 + 整体缩放）
            _buildScrollGallery(),

            // 顶部控制栏
            if (_showControls)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top,
                    left: 16,
                    right: 16,
                    bottom: 16,
                  ),
                  color: Colors.black54,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.comicName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${_chapterInfo.name} (${_currentImageIndex + 1}/${_imagePaths.length})',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
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

  Widget _buildScrollGallery() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (_imagePaths.isEmpty) {
      return const Center(
        child: Text(
          '该章节没有找到图片',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      );
    }

    // // 使用InteractiveViewer实现整体缩放
    // return InteractiveViewer(
    //   transformationController: _transformationController,
    //   minScale: _minScale,
    //   maxScale: _maxScale,
    //   panEnabled: true,
    //   scaleEnabled: true,
    //   onInteractionEnd: (details) {
    //     _handleScale();
    //     _resetControlsTimer();
    //   },
    //   child: ListView.builder(
    //     controller: _scrollController,
    //     physics: const BouncingScrollPhysics(),
    //     itemCount: _imagePaths.length,
    //     itemBuilder: (context, index) {
    //       return _buildComicImage(index);
    //     },
    //   ),
    // );
     return ListView.builder(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        itemCount: _imagePaths.length,
        itemBuilder: (context, index) {
          return _buildComicImage(index);
        },
      );
  }

  Widget _buildComicImage(int index) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;

        return Column(
          children: [
            Image.file(
              File(_imagePaths[index]),
              width: screenWidth,
              fit: BoxFit.fitWidth,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: screenWidth,
                  height: screenWidth * 1.5,
                  color: Colors.black12,
                  child: const Center(
                    child: Icon(Icons.error, color: Colors.red, size: 40),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
