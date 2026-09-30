import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:northstar/shared/widgets/heading/heading.dart';
import 'package:northstar/ui/ai/tabs/deleted_tab.dart';
import 'package:northstar/ui/ai/tabs/duplicates_tab.dart';
import 'package:northstar/ui/ai/tabs/jobs_tab.dart';
import 'package:northstar/ui/ai/tabs/overview_tab.dart';
import 'package:northstar/ui/ai/tabs/persons_tab.dart';
import 'package:northstar/ui/ai/tabs/search_tab.dart';

/// AI 媒体处理页。
///
/// 页面是否可见由 ShellPage 通过分支索引驱动（indexedStack 不销毁分支，
/// 因此不能依赖 dispose 停止轮询）。
class AiPage extends ConsumerStatefulWidget {
  const AiPage({super.key});

  @override
  ConsumerState<AiPage> createState() => _AiPageState();
}

class _AiPageState extends ConsumerState<AiPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 6, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Heading(title: 'AI 媒体处理'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(text: '概览'),
              Tab(text: '任务'),
              Tab(text: '人物'),
              Tab(text: '检索'),
              Tab(text: '去重'),
              Tab(text: '已删除'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              AiOverviewTab(),
              AiJobsTab(),
              AiPersonsTab(),
              AiSearchTab(),
              AiDuplicatesTab(),
              AiDeletedTab(),
            ],
          ),
        ),
      ],
    );
  }
}
