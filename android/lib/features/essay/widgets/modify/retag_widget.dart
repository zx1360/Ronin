import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/essay/providers/essay_data_provider.dart';
import 'package:torrid/features/essay/providers/status_provider.dart';
import 'package:torrid/features/essay/widgets/label_selector.dart';

class RetagWidget extends ConsumerWidget {
  final String essayId;
  const RetagWidget({super.key, required this.essayId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labels = ref.watch(labelsProvider);
    final essay = ref.watch(essayByIdProvider(essayId)).value;
    if (essay == null) return const SizedBox.shrink();

    final selectedLabels = labels
        .where((l) => essay.labels.contains(l.id))
        .map((l) => l.id)
        .toList();

    Future<void> onToggle(String labelId) async {
      try {
        await ref.read(essayStoreProvider).retag(essayId, labelId);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$e')));
        }
      }
    }

    final maxHeight = MediaQuery.of(context).size.height * 0.85;
    final minWidth = MediaQuery.of(context).size.width;
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight, minWidth: minWidth),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text('随笔标签', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('完成'),
              ),
            ],
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
