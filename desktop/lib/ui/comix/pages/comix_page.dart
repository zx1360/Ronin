import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:northstar/core/providers/comix/comix_providers.dart';
import 'package:northstar/shared/widgets/heading/heading.dart';
import 'package:northstar/ui/comix/tabs/comics_tab.dart';
import 'package:northstar/ui/comix/tabs/settings_tab.dart';
import 'package:northstar/ui/comix/tabs/tasks_tab.dart';
import 'package:northstar/ui/comix/tabs/url_download_tab.dart';

/// 漫画爬虫管理页：通过本地 HTTP 向 Monarch 发送指令，
/// 由 Go 端任务引擎管理 comix 爬虫的生命周期。
///
/// 布局：4 个 Tab（网址下载 / 漫画列表 / 任务面板 / 设置），
/// 各自独立滚动互不挤压；查询数据由 Go 端直查库提供（毫秒级）。
class ComixPage extends ConsumerStatefulWidget {
  const ComixPage({super.key});

  @override
  ConsumerState<ComixPage> createState() => _ComixPageState();
}

class _ComixPageState extends ConsumerState<ComixPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _pollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _onPollTick(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(comixBoardProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  /// 轮询：无条件刷新任务面板（新提交的任务也能及时出现）。
  ///
  /// 刷新前/后比较"运行中任务集合"与"已出现结果的任务数"：
  /// 只要有任务结束或新结果出现，就刷新漫画列表的下载计数，
  /// 不依赖"本页是否恰好观测到 running"（否则短任务/外部触发的任务
  /// 完成后列表计数会长期停在旧值）。
  Future<void> _onPollTick() async {
    final before = ref.read(comixBoardProvider);
    final runningBefore = before.tasks
        .where((t) => t.isRunning)
        .map((t) => t.id)
        .toSet();
    final resultsBefore = before.tasks.where((t) => t.result != null).length;

    await ref.read(comixBoardProvider.notifier).refresh();
    if (!mounted) return;

    final after = ref.read(comixBoardProvider);
    final runningAfter = after.tasks
        .where((t) => t.isRunning)
        .map((t) => t.id)
        .toSet();
    final resultsAfter = after.tasks.where((t) => t.result != null).length;

    final finishedNow = runningBefore.difference(runningAfter);
    if (finishedNow.isNotEmpty || resultsAfter > resultsBefore) {
      ref.invalidate(comixComicsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Heading(title: '漫画爬虫'),
        TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
          tabs: const [
            Tab(text: '网址下载'),
            Tab(text: '漫画列表'),
            Tab(text: '任务面板'),
            Tab(text: '设置'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              UrlDownloadTab(),
              ComicsTab(),
              TasksTab(),
              SettingsTab(),
            ],
          ),
        ),
      ],
    );
  }
}
