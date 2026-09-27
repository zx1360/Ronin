import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:torrid/features/read/views/media/image_tab.dart';
import 'package:torrid/features/read/views/media/video_tab.dart';

/// 图片视频视图 - 包含图片和视频两个子标签页
class MediaView extends ConsumerWidget {
  const MediaView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabs: const [
              Tab(text: '图片'),
              Tab(text: '视频'),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [ImageTab(), VideoTab()],
            ),
          ),
        ],
      ),
    );
  }
}
