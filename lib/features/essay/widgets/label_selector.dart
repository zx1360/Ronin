import 'package:flutter/material.dart';
import 'package:torrid/features/essay/models/label.dart';

/// 标签选择器组件
///
/// 当标签较多时，使用 [maxHeight] 限制高度，标签区域可滚动，
/// 如果在 Column 中且需要填充剩余空间，请用 Expanded/Flexible 包裹。
class LabelSelector extends StatelessWidget {
  final List<Label> labels;
  final List<String> selectedLabels;
  final void Function(String) onToggleLabel;

  /// 最大高度，超过此高度时标签区域可滚动
  /// 为 null 时根据内容自适应高度
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

    // 如果指定了 maxHeight，使用 ConstrainedBox 限制最大高度
    if (maxHeight != null) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight!),
        child: content,
      );
    }

    return content;
  }
}
