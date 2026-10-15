import 'package:flutter/material.dart';
import 'package:torrid/features/essay/models/label.dart';
import 'package:torrid/features/essay/models/label_tree.dart';

class LabelSelector extends StatelessWidget {
  final List<Label> labels;
  final List<String> selectedLabels;
  final ValueChanged<String> onToggleLabel;
  final double? maxHeight;

  const LabelSelector({
    super.key,
    required this.labels,
    required this.selectedLabels,
    required this.onToggleLabel,
    this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    final content = SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final node in flattenLabels(labels))
            Padding(
              padding: EdgeInsets.only(
                left: (node.depth.clamp(0, 6) * 16).toDouble(),
              ),
              child: FilterChip(
                avatar: Icon(
                  node.label.isHiddenRoot
                      ? Icons.visibility_off_outlined
                      : node.depth == 0
                      ? Icons.label_outline
                      : Icons.subdirectory_arrow_right,
                  size: 18,
                ),
                label: Text(
                  '${node.label.name}  ${node.label.essayCount}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                selected: selectedLabels.contains(node.label.id),
                onSelected: (_) => onToggleLabel(node.label.id),
              ),
            ),
        ],
      ),
    );
    return maxHeight == null
        ? content
        : ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight!),
            child: content,
          );
  }
}
