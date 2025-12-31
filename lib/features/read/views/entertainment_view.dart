import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/read/views/entertainment/changya_tab.dart';
import 'package:torrid/features/read/views/entertainment/hitokoto_tab.dart';
import 'package:torrid/features/read/views/entertainment/duanzi_tab.dart';
import 'package:torrid/features/read/views/entertainment/fabing_tab.dart';
import 'package:torrid/features/read/views/entertainment/kfc_tab.dart';
import 'package:torrid/features/read/views/entertainment/dad_joke_tab.dart';

class EntertainmentView extends ConsumerWidget {
  const EntertainmentView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 6,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: '随机唱歌音频'),
              Tab(text: '随机一言'),
              Tab(text: '随机段子'),
              Tab(text: '发病文学'),
              Tab(text: 'KFC 文案'),
              Tab(text: '冷笑话'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                const ChangyaTab(),
                const HitokotoTab(),
                const DuanziTab(),
                const FabingTab(),
                const KFCTab(),
                const DadJokeTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
