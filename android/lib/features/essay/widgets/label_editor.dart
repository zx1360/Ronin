import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/essay/models/label.dart';
import 'package:torrid/features/essay/models/label_tree.dart';
import 'package:torrid/features/essay/providers/essay_data_provider.dart';
import 'package:torrid/features/essay/providers/status_provider.dart';

Future<void> showLabelEditor(
  BuildContext context,
  WidgetRef ref, {
  Label? label,
  String? parentId,
}) async {
  final labels = ref.read(labelsProvider);
  final excluded = label == null
      ? <String>{}
      : labelSubtree(labels, [label.id]);
  final parents = [
    for (final node in flattenLabels(labels))
      if (!excluded.contains(node.label.id)) node.label,
  ];
  final paths = ref.read(idMapProvider);
  var name = label?.name ?? '';
  String? parent = label?.parentId ?? parentId;
  String? error;
  var busy = false;
  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(label == null ? '新增标签' : '编辑标签'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                initialValue: name,
                onChanged: (value) => name = value,
                decoration: const InputDecoration(labelText: '名称'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: parent ?? '',
                isExpanded: true,
                decoration: const InputDecoration(labelText: '上级标签'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('根级')),
                  for (final label in parents)
                    DropdownMenuItem(
                      value: label.id,
                      child: Text(
                        paths[label.id] ?? label.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: busy
                    ? null
                    : (value) => parent = value == '' ? null : value,
              ),
              const SizedBox(height: 12),
              const Text('放入“隐藏”及其子标签后，关联随笔默认隐藏，且不参与 AI 回顾。'),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: busy
                ? null
                : () async {
                    setState(() => busy = true);
                    try {
                      await ref
                          .read(essayStoreProvider)
                          .saveLabel(
                            original: label,
                            name: name,
                            parentId: parent,
                          );
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted) {
                        setState(() {
                          error = '$e';
                          busy = false;
                        });
                      }
                    }
                  },
            child: const Text('保存'),
          ),
        ],
      ),
    ),
  );
}
