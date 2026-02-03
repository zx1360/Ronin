import 'package:flutter/material.dart';

// PS: 呈现媒体内容的组件, 左右滑动可以切换前一个/后一个媒体文件.
// 媒体文件队列排序规则: 按照media_assets表的captured_at时间升序排列.
// riverpod+hive持久化当前检阅队伍及位置.
// 借助成熟组件, 图片类文件支持放大缩小/上下滑动查看, 视频类则支持播放/暂停等基本操作.
class ContentWidget extends StatelessWidget {
  const ContentWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}