import 'package:flutter/material.dart';
import 'package:torrid/core/constants/spacing.dart';
import 'package:torrid/features/read/models/random_media_models.dart';

class MediaSourcePicker extends StatelessWidget {
  const MediaSourcePicker({
    super.key,
    required this.groups,
    required this.groupIndex,
    required this.sourceIndex,
    required this.onChanged,
  });

  final List<MediaApiGroup> groups;
  final int groupIndex;
  final int sourceIndex;
  final void Function(int group, int source)? onChanged;

  @override
  Widget build(BuildContext context) {
    Widget select(
      String label,
      List<String> names,
      int index,
      ValueChanged<int> changed,
      Key key,
    ) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: DropdownButtonFormField<int>(
          key: key,
          initialValue: index,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
          ),
          isExpanded: true,
          items: [
            for (var i = 0; i < names.length; i++)
              DropdownMenuItem(
                value: i,
                child: Text(names[i], overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: onChanged == null
              ? null
              : (value) {
                  if (value != null) changed(value);
                },
        ),
      );
    }

    final group = groups[groupIndex];
    return Column(
      children: [
        if (groups.length > 1)
          select(
            'API 提供方',
            groups.map((g) => g.name).toList(),
            groupIndex,
            (index) => onChanged!(index, 0),
            ValueKey('group_$groupIndex'),
          ),
        if (group.sources.length > 1)
          select(
            '分类',
            group.sources.map((s) => s.label).toList(),
            sourceIndex,
            (index) => onChanged!(groupIndex, index),
            ValueKey('source_${groupIndex}_$sourceIndex'),
          ),
      ],
    );
  }
}
