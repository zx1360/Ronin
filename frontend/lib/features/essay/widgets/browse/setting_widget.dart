import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/core/modals/snack_bar.dart';
import 'package:torrid/features/essay/providers/essay_notifier_provider.dart';
import 'package:torrid/features/essay/providers/setting_provider.dart';
import 'package:torrid/features/essay/providers/status_provider.dart';
import 'package:torrid/features/essay/widgets/label_selector.dart';

class SettingWidget extends ConsumerWidget {
  const SettingWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(browseManagerProvider);

    final labels = ref.watch(labelsProvider);
    final selectedLabels = labels
        .where((l) => settings.selectedLabels.contains(l.id))
        .map((l) => l.id)
        .toList();

    void onToggle(String labelId) {
      ref.read(browseManagerProvider.notifier).toggleLabel(labelId);
    }

    Future<void> refreshStatistics() async {
      final notifier = ref.read(essayServiceProvider.notifier);
      // 必须按序 await：重算计数后才知道哪些标签真的没有被引用
      await notifier.refreshLabel();
      await notifier.refreshYear();
      await notifier.deleteZeroLabels();
    }

    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '浏览设置',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 16),

          const Text('排序方式:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          RadioGroup<SortType>(
            groupValue: settings.sortType,
            onChanged: (value) {
              if (value != null) {
                ref.read(browseManagerProvider.notifier).setSortType(value);
              }
            },
            child: const Column(
              children: [
                RadioListTile<SortType>(
                  title: Text('时间升序'),
                  value: SortType.ascending,
                ),
                RadioListTile<SortType>(
                  title: Text('时间降序'),
                  value: SortType.descending,
                ),
                RadioListTile<SortType>(
                  title: Text('随机'),
                  value: SortType.random,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          const Text('标签筛选:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          // 使用 Flexible 让标签选择器在空间不足时可滚动
          Flexible(
            child: LabelSelector(
              labels: labels,
              selectedLabels: selectedLabels,
              onToggleLabel: onToggle,
            ),
          ),

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              ElevatedButton(
                onPressed: () async {
                  try {
                    await refreshStatistics();
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
    );
  }
}
