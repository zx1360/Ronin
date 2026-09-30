import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:northstar/core/providers/comix/comix_providers.dart';
import 'package:northstar/shared/widgets/heading/heading.dart';
import 'package:northstar/ui/comix/tabs/comics_library_tab.dart';
import 'package:northstar/ui/comix/tabs/tasks_tab.dart';
import 'package:northstar/ui/comix/tabs/url_download_tab.dart';

/// 漫画资源页：把爬虫操作与书库管理合并到同一处。
///
/// 布局：3 个 Tab（网址下载 / 漫画库 / 任务面板），各自独立滚动互不挤压；
/// 查询数据由 Go 端直查库提供（毫秒级）。
class ComixPage extends ConsumerStatefulWidget {
  const ComixPage({super.key});

  @override
  ConsumerState<ComixPage> createState() => _ComixPageState();
}

class _ComixPageState extends ConsumerState<ComixPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await ref.read(comixBoardProvider.notifier).refresh();
    });
  }

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
        const Heading(title: '漫画资源'),
        TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
          tabs: const [
            Tab(text: '网址下载'),
            Tab(text: '漫画库'),
            Tab(text: '任务面板'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [UrlDownloadTab(), ComicsLibraryTab(), TasksTab()],
          ),
        ),
      ],
    );
  }
}
