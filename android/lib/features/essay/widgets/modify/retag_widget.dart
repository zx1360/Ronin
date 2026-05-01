import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/essay/providers/essay_notifier_provider.dart';
import 'package:torrid/features/essay/providers/setting_provider.dart';
import 'package:torrid/features/essay/providers/status_provider.dart';
import 'package:torrid/features/essay/widgets/label_selector.dart';

class RetagWidget extends ConsumerWidget {
  const RetagWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labels = ref.watch(labelsProvider);
    final essay = ref.watch(contentServerProvider);
    final selectedLabels = labels
        .where((l) => essay!.labels.contains(l.id))
        .map((l) => l.id)
        .toList();

    void onToggle(String labelId) {
      ref.read(essayServiceProvider.notifier).retag(essay!.id, labelId);
    }

    final maxHeight = MediaQuery.of(context).size.height * 0.85;
    final minWidth = MediaQuery.of(context).size.width;
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight, minWidth: minWidth),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '重选标签',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // 使用 Flexible 让标签选择器在空间不足时可滚动
          Flexible(
            child: LabelSelector(
              labels: labels,
              selectedLabels: selectedLabels,
              onToggleLabel: onToggle,
            ),
          ),
        ],
      ),
    );
  }
}
