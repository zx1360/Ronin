import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/read/views/utilities/moyu_tab.dart';
import 'package:torrid/features/read/views/utilities/lyric_tab.dart';
import 'package:torrid/features/read/views/utilities/baike_tab.dart';
import 'package:torrid/features/read/views/utilities/health_tab.dart';

class UtilitiesView extends ConsumerWidget {
  const UtilitiesView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
           TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: '摸鱼日报'),
              Tab(text: '歌词搜索'),
              Tab(text: '百科词条'),
              Tab(text: '健康分析'),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                MoyuTab(),
                LyricTab(),
                BaikeTab(),
                HealthTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

