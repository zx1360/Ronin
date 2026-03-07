import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:torrid/features/read/views/entertainment/random_media_tab.dart';
import 'package:torrid/features/read/views/entertainment/sentence_tab.dart';

class EntertainmentView extends ConsumerWidget {
  const EntertainmentView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabs: const [
              Tab(text: '趣味合集'),
              Tab(text: '随机图片/视频'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: const [SentenceTab(), RandomMediaTab()],
            ),
          ),
        ],
      ),
    );
  }
}
