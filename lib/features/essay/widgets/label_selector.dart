import 'package:flutter/material.dart';
import 'package:torrid/features/essay/models/label.dart';

// TODO: 想要实现的是标签多起来后, 其他组件固定, 标签可滚动, 还不知道躲起来后的效果.
class LabelSelector extends StatelessWidget {
  final List<Label> labels;
  final List<String> selectedLabels;
  final void Function(String) onToggleLabel;

  const LabelSelector({
    super.key,
    required this.labels,
    required this.selectedLabels,
    required this.onToggleLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: labels.map((label) {
          final isSelected = selectedLabels.contains(label.id);
          return FilterChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label.name),
                const SizedBox(width: 2),
                Text(
                  label.essayCount.toString(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isSelected 
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                ),
              ],
            ),
            selected: isSelected,
            onSelected: (_) => onToggleLabel(label.id),
            selectedColor: Theme.of(context).colorScheme.primaryContainer,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
          );
        }).toList(),
      ),
    );
  }
}
