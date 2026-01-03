import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:torrid/features/read/views/periodic/sixty_seconds_tab.dart';
import 'package:torrid/features/read/views/periodic/bing_wallpaper_tab.dart';
import 'package:torrid/features/read/views/periodic/epic_games_tab.dart';

class PeriodicView extends ConsumerWidget {
  const PeriodicView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabs: const [
              Tab(text: '60秒读懂世界'),
              Tab(text: '必应每日壁纸'),
              Tab(text: 'Epic 免费游戏'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: const [
                SixtySecondsTab(),
                BingWallpaperTab(),
                EpicGamesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
