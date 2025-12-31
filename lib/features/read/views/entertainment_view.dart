import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:torrid/features/read/views/entertainment/changya_tab.dart';
import 'package:torrid/features/read/views/entertainment/entertaiment_tab.dart';

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
              Tab(text: '随机唱歌音频'),
              Tab(text: '趣味合集'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: const [
                ChangyaTab(),
                EntertainmentCombinedPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


