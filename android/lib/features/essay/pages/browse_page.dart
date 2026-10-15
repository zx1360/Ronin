import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/essay/pages/drafts_page.dart';
import 'package:torrid/features/essay/models/essay_reread.dart';
import 'package:torrid/features/essay/pages/detail_page.dart';
import 'package:torrid/features/essay/pages/search_page.dart';
import 'package:torrid/features/essay/providers/box_provider.dart';
import 'package:torrid/features/essay/providers/setting_provider.dart';
import 'package:torrid/features/essay/providers/status_provider.dart';
import 'package:torrid/features/essay/services/essay_draft_store.dart';
import 'package:torrid/features/essay/pages/browse_body.dart';
import 'package:torrid/features/essay/pages/write_page.dart';
import 'package:torrid/features/essay/widgets/browse/expandable_fab.dart';

import 'package:torrid/features/essay/widgets/browse/setting_widget.dart';

class EssayBrowsePage extends ConsumerStatefulWidget {
  const EssayBrowsePage({super.key});

  @override
  ConsumerState<EssayBrowsePage> createState() => _EssayBrowsePageState();
}

class _EssayBrowsePageState extends ConsumerState<EssayBrowsePage> {
  final GlobalKey<BrowseBodyState> _browseBodyKey = GlobalKey();
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
      ref.read(contentServerProvider.notifier).switchEssay(essay);
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const EssayDetailPage()),
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
    ref.watch(contentServerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('随笔'),
        actions: [
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
            icon: const Icon(Icons.settings),
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
          Expanded(child: BrowseBody(key: _browseBodyKey)),
        ],
      ),
      floatingActionButton: ExpandableFab(
        distance: 70,
        actions: [
          FabAction(
            icon: Icons.vertical_align_top,
            label: '回到顶部',
            onPressed: () {
              _browseBodyKey.currentState?.scrollToTop();
            },
          ),
          FabAction(
            icon: Icons.edit,
            label: '写随笔',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EssayWritePage()),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showBrowseSettings(BuildContext context) {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SettingWidget(),
    );
  }
}
