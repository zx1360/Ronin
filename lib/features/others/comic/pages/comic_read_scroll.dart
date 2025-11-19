import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/comic/models/chapter_info.dart';
import 'package:torrid/features/others/comic/models/comic_info.dart';
import 'package:torrid/features/others/comic/provider/notifier_provider.dart';
import 'package:torrid/features/others/comic/provider/status_provider.dart';
import 'package:torrid/features/others/comic/widgets/comic_browse/bottom_bar.dart';
import 'package:torrid/features/others/comic/widgets/comic_browse/comic_image.dart';
import 'package:torrid/features/others/comic/widgets/comic_browse/top_bar.dart';

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
  late Timer _controlsTimer;
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
      });
    });
  }

  @override
  void dispose() {
    _controlsTimer.cancel();
    _scrollController.dispose();
    super.dispose();
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

  // 上一章节
  void _prevChapter() {
    if (chapterIndex > 0) {
      chapterIndex--;
      currentChapter = chapterInfos[chapterIndex];
      _currentImageIndex = 0;
      setState(() {
        images = currentChapter!.images;
        _scrollController.jumpTo(0);
      });
      _controlsTimer.cancel();
      init();
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
        _scrollController.jumpTo(0);
      });
      _controlsTimer.cancel();
      init();
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
            // 漫画阅读区域（下拉式 + 整体缩放）
            _buildScrollGallery(context),

            // 顶部控制栏
            if (_showControls)
              TopControllBar(
                comicName: widget.comicInfo.comicName,
                chapterName: currentChapter?.dirName ?? "",
                currentNum: _currentImageIndex,
                totalNum: images.length,
                saveFunc: () {},
              ),

            // 底部控制栏
            if (_showControls)
              BottomControllBar(
                prevFunc: _prevChapter,
                nextFunc: _nextChapter,
                slideVal: 0,
                onSlideFunc: (_) {},
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
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      itemCount: images.length,
      itemBuilder: (context, index) {
        final image = images[index];
        final width = image['width'];
        final height = image['height'] * (maxWidth / width);
        return SizedBox(
          width: maxWidth,
          height: height,
          child: ComicImage(path: images[index]['path']),
        );
      },
    );
  }
}
