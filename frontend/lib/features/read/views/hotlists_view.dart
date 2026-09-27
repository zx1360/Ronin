import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:torrid/features/read/views/hotlists/toutiao_tab.dart';
import 'package:torrid/features/read/views/hotlists/zhihu_tab.dart';
import 'package:torrid/features/read/views/hotlists/baidu_tieba_tab.dart';

class HotlistsView extends ConsumerWidget {
  const HotlistsView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: '头条热榜'),
              Tab(text: '知乎热榜'),
              Tab(text: '百度贴吧'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                const ToutiaoTab(),
                const ZhihuTab(),
                const BaiduTiebaTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
