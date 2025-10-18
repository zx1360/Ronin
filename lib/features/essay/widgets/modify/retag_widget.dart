import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/essay/providers/notifier_provider.dart';
import 'package:torrid/features/essay/providers/status_provider.dart';

class RetagWidget extends ConsumerWidget {
  const RetagWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labels = ref.watch(labelsProvider);

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

          SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: labels.map((label) {
                final isSelected = ref
                    .watch(contentServerProvider)!
                    .labels
                    .contains(label.id);
                return FilterChip(
                  label: Text(label.name),
                  selected: isSelected,
                  onSelected: (_) {
                    ref
                        .read(essayServerProvider.notifier)
                        .retag(ref.watch(contentServerProvider)!.id, label);
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
