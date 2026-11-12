import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/essay/models/label_tree.dart';
import 'package:torrid/features/essay/pages/labels_page.dart';
import 'package:torrid/features/essay/providers/setting_provider.dart';
import 'package:torrid/features/essay/providers/status_provider.dart';
import 'package:torrid/features/essay/widgets/label_selector.dart';

class SettingWidget extends ConsumerStatefulWidget {
  const SettingWidget({super.key});

  @override
  ConsumerState<SettingWidget> createState() => _SettingWidgetState();
}

class _SettingWidgetState extends ConsumerState<SettingWidget> {
  bool _exclude = false;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(browseManagerProvider);
    final manager = ref.read(browseManagerProvider.notifier);
    final labels = ref.watch(labelsProvider);
    final hidden = hiddenLabelIds(labels);
    final filterLabels = settings.showHidden
        ? labels
        : labels.where((label) => !hidden.contains(label.id)).toList();
    final selectableIds = filterLabels.map((label) => label.id).toSet();
    final parents = filterLabels.map((label) => label.parentId).toSet();
    final included = settings.selectedLabels.keys
        .where(selectableIds.contains)
        .length;
    final excluded = settings.excludedLabels.keys
        .where(selectableIds.contains)
        .length;
    final selection = _exclude
        ? settings.excludedLabels
        : settings.selectedLabels;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '浏览设置',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
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
              onSelectionChanged: (values) => manager.setSortType(values.first),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('显示隐藏随笔'),
              subtitle: const Text('统计和 AI 回顾始终排除隐藏内容。'),
              value: settings.showHidden,
              onChanged: (value) => manager.setShowHidden(value, hidden),
            ),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: false, label: Text('包含 ($included)')),
                ButtonSegment(value: true, label: Text('排除 ($excluded)')),
              ],
              selected: {_exclude},
              onSelectionChanged: (values) =>
                  setState(() => _exclude = values.first),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '匹配任一包含标签，且避开所有排除标签。父标签可切换为仅本级。',
                style: TextStyle(fontSize: 12),
              ),
            ),
            LabelSelector(
              labels: filterLabels,
              selectedLabels: selection.keys
                  .where(selectableIds.contains)
                  .toList(),
              selectionHints: {
                for (final entry in selection.entries)
                  if (parents.contains(entry.key))
                    entry.key: entry.value == LabelFilterMode.subtree
                        ? '含子标签'
                        : '仅本级',
              },
              onToggleLabel: (id) => manager.toggleLabel(
                id,
                hasChildren: parents.contains(id),
                exclude: _exclude,
              ),
              onRemoveLabel: (id) => manager.removeLabel(id, exclude: _exclude),
              maxHeight: MediaQuery.sizeOf(context).height * 0.42,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () {
                    final navigator = Navigator.of(context);
                    navigator.pop();
                    navigator.push(
                      MaterialPageRoute(
                        builder: (_) => const EssayLabelsPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.account_tree_outlined),
                  label: const Text('管理标签层级'),
                ),
                TextButton(
                  onPressed: settings.hasFilters ? manager.clearFilters : null,
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
