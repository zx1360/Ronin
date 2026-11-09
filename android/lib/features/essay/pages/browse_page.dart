import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/essay/pages/essay_label_suggestions_page.dart';
import 'package:torrid/features/essay/pages/drafts_page.dart';
import 'package:torrid/features/essay/models/essay_reread.dart';
import 'package:torrid/features/essay/pages/detail_page.dart';
import 'package:torrid/features/essay/pages/search_page.dart';
import 'package:torrid/features/essay/providers/box_provider.dart';
import 'package:torrid/features/essay/providers/status_provider.dart';
import 'package:torrid/features/essay/services/essay_draft_store.dart';
import 'package:torrid/features/essay/pages/browse_body.dart';
import 'package:torrid/features/essay/pages/write_page.dart';
import 'package:torrid/features/essay/providers/setting_provider.dart';

import 'package:torrid/features/essay/widgets/browse/setting_widget.dart';

class EssayBrowsePage extends ConsumerStatefulWidget {
  const EssayBrowsePage({super.key});

  @override
  ConsumerState<EssayBrowsePage> createState() => _EssayBrowsePageState();
}

class _EssayBrowsePageState extends ConsumerState<EssayBrowsePage> {
  final _rereadPicker = EssayRereadPicker();
  bool _opening = false;

  Future<void> _reread() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final essays = await ref.read(filteredEssaysProvider.future);
      if (!mounted) return;
      final selected = _rereadPicker.pick(essays, ref.read(labelsProvider));
      final essay = selected == null
          ? null
          : ref.read(essayBoxProvider).get(selected.id);
      if (essay == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('当前筛选范围内还没有可重读的往日随笔')));
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EssayDetailPage(essayId: essay.id)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('读取失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(browseManagerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('随笔'),
        actions: [
          IconButton(
            tooltip: 'AI 标签建议',
            icon: const Icon(Icons.auto_awesome_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const EssayLabelSuggestionsPage(),
              ),
            ),
          ),
          IconButton(
            tooltip: '本机草稿',
            icon: Badge.count(
              count: ref.watch(essayDraftsProvider).valueOrNull?.length ?? 0,
              isLabelVisible:
                  (ref.watch(essayDraftsProvider).valueOrNull?.isNotEmpty ??
                  false),
              child: const Icon(Icons.drafts_outlined),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EssayDraftsPage()),
            ),
          ),
          IconButton(
            tooltip: '浏览设置',
            icon: Badge(
              isLabelVisible: settings.hasFilters,
              child: const Icon(Icons.tune),
            ),
            onPressed: () => _showBrowseSettings(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EssaySearchPage(),
                      ),
                    ),
                    icon: const Icon(Icons.search),
                    label: const Text('全文搜索'),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: _opening ? null : _reread,
                    icon: const Icon(Icons.history_edu_outlined),
                    label: const Text('重读一篇'),
                  ),
                ),
              ],
            ),
          ),
          if (settings.hasFilters)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      [
                        if (settings.selectedLabels.isNotEmpty)
                          '${settings.selectedLabels.length} 个标签筛选',
                        if (settings.showHidden) '含隐藏随笔',
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: ref
                        .read(browseManagerProvider.notifier)
                        .clearFilters,
                    child: const Text('重置'),
                  ),
                ],
              ),
            ),
          const Expanded(child: BrowseBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.edit_outlined),
        label: const Text('写随笔'),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EssayWritePage()),
        ),
      ),
    );
  }

  void _showBrowseSettings(BuildContext context) {
    showModalBottomSheet(
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => AnimatedPadding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        duration: const Duration(milliseconds: 180),
        child: const SettingWidget(),
      ),
    );
  }
}
