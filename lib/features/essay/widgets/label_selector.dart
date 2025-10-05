import 'package:flutter/material.dart';
import 'package:torrid/features/essay/models/label.dart';

class LabelSelector extends StatelessWidget {
  final List<Label> labels;
  final List<String> selectedLabels;
  final Function(String) onToggleLabel;

  const LabelSelector({
    super.key,
    required this.labels,
    required this.selectedLabels,
    required this.onToggleLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: labels.map((label) {
        final isSelected = selectedLabels.contains(label.id);
        return FilterChip(
          label: Text(label.name),
          selected: isSelected,
          onSelected: (_) => onToggleLabel(label.id),
          selectedColor: Theme.of(context).colorScheme.primaryContainer,
          backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
        );
      }).toList(),
    );
  }
}