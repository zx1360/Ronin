import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/core/modals/snack_bar.dart';
import 'package:torrid/features/essay/providers/essay_notifier_provider.dart';
import 'package:torrid/features/essay/providers/setting_provider.dart';
import 'package:torrid/features/essay/providers/status_provider.dart';
import 'package:torrid/features/essay/widgets/label_selector.dart';
import 'package:torrid/features/essay/models/label_tree.dart';
import 'package:torrid/features/essay/pages/labels_page.dart';

class SettingWidget extends ConsumerWidget {
  const SettingWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(browseManagerProvider);

    final labels = ref.watch(labelsProvider);
    final hidden = hiddenLabelIds(labels);
    final filterLabels = settings.showHidden
        ? labels
        : labels.where((l) => !hidden.contains(l.id)).toList();
    final parents = filterLabels.map((l) => l.parentId).toSet();

    void onToggle(String labelId) {
      ref
          .read(browseManagerProvider.notifier)
          .toggleLabel(labelId, hasChildren: parents.contains(labelId));
    }

    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text('浏览设置', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('完成'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<SortType>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: SortType.descending, label: Text('最新在前')),
                ButtonSegment(value: SortType.ascending, label: Text('最早在前')),
                ButtonSegment(value: SortType.random, label: Text('随机')),
              ],
              selected: {settings.sortType},
              onSelectionChanged: (values) => ref
                  .read(browseManagerProvider.notifier)
                  .setSortType(values.first),
            ),
            const SizedBox(height: 20),
            const Text('标签筛选:', style: TextStyle(fontWeight: FontWeight.bold)),
            SwitchListTile(
              title: const Text('显示隐藏随笔'),
              subtitle: const Text('含子标签。统计和 AI 回顾始终排除隐藏内容。'),
              value: settings.showHidden,
              onChanged: (value) => ref
                  .read(browseManagerProvider.notifier)
                  .setShowHidden(value, hidden),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                '父标签可依次切换：含子标签 → 仅本级 → 取消',
                style: TextStyle(fontSize: 12),
              ),
            ),
            LabelSelector(
              labels: filterLabels,
              selectedLabels: settings.selectedLabels.keys.toList(),
              selectionHints: {
                for (final entry in settings.selectedLabels.entries)
                  if (parents.contains(entry.key))
                    entry.key: entry.value == LabelFilterMode.subtree
                        ? '含子标签'
                        : '仅本级',
              },
              onToggleLabel: onToggle,
              onRemoveLabel: ref
                  .read(browseManagerProvider.notifier)
                  .removeLabel,
              maxHeight: MediaQuery.sizeOf(context).height * 0.42,
            ),

            const SizedBox(height: 16),

            TextButton.icon(
              onPressed: () {
                final navigator = Navigator.of(context);
                navigator.pop();
                navigator.push(
                  MaterialPageRoute(builder: (_) => const EssayLabelsPage()),
                );
              },
              icon: const Icon(Icons.account_tree_outlined),
              label: const Text('管理标签层级'),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await ref
                          .read(essayServiceProvider.notifier)
                          .refreshStatistics();
                      if (context.mounted) displaySnackBar(context, '统计信息已刷新');
                    } catch (e) {
                      if (context.mounted) displaySnackBar(context, '刷新失败: $e');
                    }
                  },
                  child: const Text('刷新信息'),
                ),
                ElevatedButton(
                  onPressed: () {
                    ref.read(browseManagerProvider.notifier).clearFilters();
                  },
                  child: const Text('重置筛选'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
