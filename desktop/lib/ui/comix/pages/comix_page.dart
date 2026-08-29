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
  final Set<String> _runningTaskIds = <String>{};
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

  /// 轮询：任务运行期间刷新面板；任务结束刷新漫画列表。
  Future<void> _onPollTick() async {
    final board = ref.read(comixBoardProvider);
    final runningNow = board.tasks
        .where((t) => t.isRunning)
        .map((t) => t.id)
        .toSet();
    final finishedNow = _runningTaskIds.difference(runningNow);
    final hadRunning = _runningTaskIds.isNotEmpty;
    _runningTaskIds
      ..clear()
      ..addAll(runningNow);

    if (board.hasRunningTasks || hadRunning) {
      await ref.read(comixBoardProvider.notifier).refresh();
    }
    if (finishedNow.isNotEmpty) {
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
