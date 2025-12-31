import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:torrid/features/read/views/utilities/moyu_tab.dart';
import 'package:torrid/features/read/views/utilities/lyric_tab.dart';

class UtilitiesView extends ConsumerWidget {
  const UtilitiesView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
           TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: '摸鱼日报'),
              Tab(text: '歌词搜索'),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                MoyuTab(),
                LyricTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

