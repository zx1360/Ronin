import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/read/views/hotlists/toutiao_tab.dart';
import 'package:torrid/features/read/views/hotlists/weibo_tab.dart';
import 'package:torrid/features/read/views/hotlists/zhihu_tab.dart';
import 'package:torrid/features/read/views/hotlists/hacker_news_tab.dart';
import 'package:torrid/features/read/views/hotlists/baidu_hot_tab.dart';
import 'package:torrid/features/read/views/hotlists/baidu_tieba_tab.dart';
import 'package:torrid/features/read/views/hotlists/baidu_teleplay_tab.dart';
import 'package:torrid/features/read/views/hotlists/bili_tab.dart';
import 'package:torrid/features/read/views/hotlists/douyin_tab.dart';
import 'package:torrid/features/read/views/hotlists/quark_tab.dart';
import 'package:torrid/features/read/views/hotlists/rednote_tab.dart';

class HotlistsView extends ConsumerWidget {
  const HotlistsView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 13,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
            indicatorColor: Theme.of(context).colorScheme.primary,
            tabs: [
              Tab(text: '头条热榜'),
              Tab(text: '微博热搜'),
              Tab(text: '知乎热榜'),
              Tab(text: 'HackerNews Top'),
              Tab(text: 'HackerNews New'),
              Tab(text: 'HackerNews Best'),
              Tab(text: '百度热榜'),
              Tab(text: '百度贴吧'),
              Tab(text: '百度电视剧榜'),
              Tab(text: 'B站热榜'),
              Tab(text: '抖音热榜'),
              Tab(text: '夸克热榜'),
              Tab(text: '小红书热榜'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                const ToutiaoTab(),
                const WeiboTab(),
                const ZhihuTab(),
                const HackerNewsTab(kind: 'top'),
                const HackerNewsTab(kind: 'new'),
                const HackerNewsTab(kind: 'best'),
                const BaiduHotTab(),
                const BaiduTiebaTab(),
                const BaiduTeleplayTab(),
                const BiliTab(),
                const DouyinTab(),
                const QuarkTab(),
                const RednoteTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
// tabs moved to views/hotlists/*
