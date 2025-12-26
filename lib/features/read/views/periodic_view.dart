import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/read/views/periodic/sixty_seconds_tab.dart';
import 'package:torrid/features/read/views/periodic/ai_news_tab.dart';
import 'package:torrid/features/read/views/periodic/bing_wallpaper_tab.dart';
import 'package:torrid/features/read/views/periodic/today_in_history_tab.dart';
import 'package:torrid/features/read/views/periodic/epic_games_tab.dart';

class PeriodicView extends ConsumerWidget {
  const PeriodicView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
            indicatorColor: Theme.of(context).colorScheme.primary,
            tabs: const [
              Tab(text: '60秒读懂世界'),
              Tab(text: 'AI资讯'),
              Tab(text: '必应每日壁纸'),
              Tab(text: '历史上的今天'),
              Tab(text: 'Epic 免费游戏'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: const [
                SixtySecondsTab(),
                AiNewsTab(),
                BingWallpaperTab(),
                TodayInHistoryTab(),
                EpicGamesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
