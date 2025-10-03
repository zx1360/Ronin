// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:torrid/core/services/io/io_service.dart';
import 'comic_detail.dart';

class ComicReadPage extends StatefulWidget {
  final List<ChapterInfo> chapters;
  final int currentChapter;
  final String comicName;

  const ComicReadPage({
    super.key,
    required this.chapters,
    required this.currentChapter,
    required this.comicName,
  });

  @override
  State<ComicReadPage> createState() => _ComicReadPageState();
}

class _ComicReadPageState extends State<ComicReadPage> {
  late int _currentChapter = widget.currentChapter;
  late ChapterInfo _chapterInfo = widget.chapters[_currentChapter];
  // 是否展示操作栏
  bool _showControls = true;
  // 图片加载相关
  bool _isLoading = true;
  List<String> _imagePaths = [];
  int _currentIndex = 0;
  late PageController _pageController;
  // 自动关闭操作栏计时器
  late Timer _controlsTimer;
  final Duration closeBarDuration = const Duration(seconds: 4);
  final Duration switchImgDuration = const Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    init();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _controlsTimer.cancel();
    // 退出时恢复系统UI
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
  }

  // 获取所有图片文件的path
  Future<void> _loadChapterImages() async {
    try {
      final chapterDir = Directory(_chapterInfo.path);

      // 获取所有图片并按名称排序
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

      // 按文件名排序（假设文件名是数字）
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
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context as BuildContext,
        ).showSnackBar(SnackBar(content: Text('加载图片失败: ${e.toString()}')));
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 导航到上一页
  void _prevImage() {
    if (_currentIndex > 0) {
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
    if (_currentIndex < _imagePaths.length - 1) {
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
    if (_currentChapter > 0) {
      setState(() {
        _currentChapter--;
        _chapterInfo = widget.chapters[_currentChapter];
        _currentIndex = 0;

        _controlsTimer.cancel();
        init();
        _pageController.jumpToPage(0);
      });
    }
  }

  // 下一章节
  void _nextChapter() {
    if (_currentChapter < widget.chapters.length - 1) {
      setState(() {
        _currentChapter++;
        _chapterInfo = widget.chapters[_currentChapter];
        _currentIndex = 0;

        _controlsTimer.cancel();
        init();
        _pageController.jumpToPage(0);
      });
    }
  }

  Future<void> _saveThisImage(BuildContext context) async {
    // 检查是否有可保存的图片
    if (_imagePaths.isEmpty ||
        _currentIndex < 0 ||
        _currentIndex >= _imagePaths.length) {
      _showSnackBar(context, "没有可保存的图片");
      return;
    }

    try {
      // 获取当前图片文件
      final sourceFile = File(_imagePaths[_currentIndex]);
      if (!await sourceFile.exists()) {
        _showSnackBar(context, "图片文件不存在");
        return;
      }

      // 生成保存的文件名（漫画名_章节号_页码.扩展名）
      final fileExtension = sourceFile.path.split('.').last;
      final fileName =
          "${widget.comicName}_"
          "第${_chapterInfo.chapterNumber}章_"
          "第${_currentIndex + 1}页."
          "$fileExtension";
      IoService.saveThisImage(_imagePaths[_currentIndex], fileName);

      _showSnackBar(context, "图片已保存: $fileName");
    } catch (e) {
      _showSnackBar(context, "保存失败: ${e.toString()}");
      print("保存图片错误: $e");
    }
  }

  // 显示提示信息
  void _showSnackBar(BuildContext context, String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
    }
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
                      // 返回按钮
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),

                      // 标题信息
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
                              '${_chapterInfo.name} (${_currentIndex + 1}/${_imagePaths.length})',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 保存当前图片按钮
                      IconButton(
                        icon: Icon(Icons.save_alt_rounded, color: Colors.white),
                        onPressed: (){_saveThisImage(context);},
                      ),
                    ],
                  ),
                ),
              ),

            // TODO: 也许以后重构下, 把更多的状态使用riverpod管理.
            // 底部控制栏 - 只有当图片数量大于1时才显示进度条和翻页按钮
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
                      // 进度条
                      Expanded(
                        child: Slider(
                          value: _getSliderValue(),
                          onChanged: (value) {
                            if (_imagePaths.isNotEmpty) {
                              // 比较来看, 还是直接无动画的跳转比较好.
                              _pageController.jumpToPage(
                                (value * (_imagePaths.length - 1)).round(),
                              );
                            }
                            _resetControlsTimer();
                          },
                          activeColor: Colors.white,
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
            // 当只有一张图片时，简化控制栏
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

  // 获取滑块进度条.
  double _getSliderValue() {
    if (_imagePaths.length <= 1) {
      return 0.0;
    }
    return _currentIndex / (_imagePaths.length - 1);
  }

  Widget _buildGallery() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_imagePaths.isEmpty) {
      return const Center(child: Text('该章节没有找到图片'));
    }

    return PhotoViewGallery.builder(
      itemCount: _imagePaths.length,
      builder: (context, index) {
        return PhotoViewGalleryPageOptions(
          imageProvider: FileImage(File(_imagePaths[index])),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 2,
        );
      },
      scrollPhysics: const ClampingScrollPhysics(),
      backgroundDecoration: const BoxDecoration(color: Colors.black),
      // scrollDirection: Axis.vertical,
      // loadingBuilder:(context, event) => Center() ,
      
      onPageChanged: (index) {
        setState(() {
          _currentIndex = index;
        });
      },
      pageController: _pageController,
    );
  }
}
