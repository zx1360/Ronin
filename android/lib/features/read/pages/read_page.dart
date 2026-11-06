import 'package:flutter/material.dart';

import 'package:torrid/app/theme/theme_book.dart';
import 'package:torrid/features/read/views/periodic_view.dart';
import 'package:torrid/features/read/views/media_view.dart';
import 'package:torrid/features/read/views/hotlists_view.dart';
import 'package:torrid/features/read/views/entertainment_view.dart';

class ReadPage extends StatelessWidget {
  const ReadPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('阅读页'),
          bottom: AppTheme.appBarTabs(
            colorScheme,
            tabs: const [
              Tab(text: '周期资讯'),
              Tab(text: '图片视频'),
              Tab(text: '热门榜单'),
              Tab(text: '消遣娱乐'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            PeriodicView(),
            MediaView(),
            HotlistsView(),
            EntertainmentView(),
          ],
        ),
      ),
    );
  }
}
