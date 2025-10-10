import 'package:flutter/material.dart';

import 'package:torrid/features/others/tuntun/widgets/bottom_bar.dart';
import 'package:torrid/features/others/tuntun/widgets/top_bar.dart';
import 'package:torrid/features/others/tuntun/widgets/video_item.dart';

import '../models/data_class.dart';

class TuntunPage extends StatefulWidget {
  const TuntunPage({super.key});

  @override
  State<TuntunPage> createState() => _TuntunPageState();
}

class _TuntunPageState extends State<TuntunPage> {
  // 控制页面切换的控制器
  final PageController _pageController = PageController();
  // 当前页面索引
  int _currentIndex = 0;
  // 视频数据列表
  List<VideoData> _videoList = [];
  // 加载状态
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // 初始化加载视频数据
    _loadInitialVideos();
  }

  // 初始化加载视频数据
  Future<void> _loadInitialVideos() async {
    try {
      // TODO: 替换为实际的API调用
      List<VideoData> videos = await _fetchVideos(0, 5);
      setState(() {
        _videoList = videos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // 显示错误提示
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('加载视频失败: $e')));
    }
  }

  // 模拟从服务器获取视频数据
  Future<List<VideoData>> _fetchVideos(int startIndex, int count) async {
    // TODO: 替换为实际的API请求
    await Future.delayed(const Duration(milliseconds: 500));

    List<VideoData> result = [];
    for (int i = 0; i < count; i++) {
      result.add(
        VideoData(
          id: startIndex + i,
          title: '视频 ${startIndex + i + 1}',
          url: 'https://example.com/video/${startIndex + i}.mp4',
          // 实际应用中应使用真实的视频URL
        ),
      );
    }
    return result;
  }

  // 加载更多视频
  Future<void> _loadMoreVideos(int direction) async {
    // direction: -1 表示向前加载, 1 表示向后加载
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      int startIndex = direction == 1
          ? _videoList.isNotEmpty
                ? _videoList.last.id + 1
                : 0
          : _videoList.isNotEmpty
          ? _videoList.first.id - 5
          : 0;

      List<VideoData> newVideos = await _fetchVideos(startIndex, 5);

      setState(() {
        if (direction == 1) {
          _videoList.addAll(newVideos);
        } else {
          _videoList.insertAll(0, newVideos);
          // 调整页面控制器位置
          _pageController.jumpToPage(
            _pageController.page!.toInt() + newVideos.length,
          );
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('加载更多视频失败: $e')));
    }
  }

  // 切换到指定页面
  void _navigateToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.ease,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // 不使用AppBar，我们自定义顶部操作栏
      body: SafeArea(
        // 只在底部添加安全区域，顶部状态栏不使用安全区域
        top: false,
        child: Stack(
          children: [
            // 主内容区域 - 视频浏览
            _buildVideoContent(),

            // 顶部操作栏
            TopBar(),

            // 底部工具栏
            BottomBar(),
          ],
        ),
      ),
    );
  }

  // 构建视频内容区域
  Widget _buildVideoContent() {
    if (_isLoading && _videoList.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.horizontal, // 左右滑动
      itemCount: _videoList.length,
      onPageChanged: (index) {
        setState(() {
          _currentIndex = index;
        });

        // 当接近列表末尾时加载更多
        if (index > _videoList.length - 3) {
          _loadMoreVideos(1);
        }

        // 当接近列表开头时向前加载
        if (index < 2) {
          _loadMoreVideos(-1);
        }
      },
      itemBuilder: (context, index) {
        return VideoItem(video: _videoList[index]);
      },
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
