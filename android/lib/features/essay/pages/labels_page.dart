import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/core/modals/confirm_modal.dart';
import 'package:torrid/features/essay/models/label_tree.dart';
import 'package:torrid/features/essay/providers/essay_notifier_provider.dart';
import 'package:torrid/features/essay/providers/status_provider.dart';
import 'package:torrid/features/essay/widgets/label_editor.dart';

class EssayLabelsPage extends ConsumerWidget {
  const EssayLabelsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labels = ref.watch(labelsProvider);
    final nodes = flattenLabels(labels);
    return Scaffold(
      appBar: AppBar(
        title: const Text('随笔标签'),
        actions: [
          IconButton(
            tooltip: '新增标签',
            onPressed: () => showLabelEditor(context, ref),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: nodes.length,
        itemBuilder: (context, index) {
          final node = nodes[index];
          final label = node.label;
          return ListTile(
            contentPadding: EdgeInsets.only(
              left: 16 + (node.depth.clamp(0, 6) * 16).toDouble(),
              right: 8,
            ),
            leading: Icon(
              label.isHiddenRoot
                  ? Icons.visibility_off_outlined
                  : Icons.label_outline,
            ),
            title: Text(label.name),
            subtitle: Text(
              label.isHiddenRoot
                  ? '系统根标签 · 不可修改或删除'
                  : '${label.essayCount} 篇随笔',
            ),
            onTap: label.isHiddenRoot
                ? null
                : () => showLabelEditor(context, ref, label: label),
            trailing: label.isHiddenRoot
                ? null
                : IconButton(
                    tooltip: '删除未使用标签',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => showConfirmDialog(
                      context: context,
                      title: '删除标签',
                      content: '仅可删除未被使用且没有子标签的标签。确认删除“${label.name}”？',
                      confirmFunc: () async {
                        try {
                          await ref
                              .read(essayServiceProvider.notifier)
                              .deleteLabel(label);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text('$e')));
                          }
                        }
                      },
                    ),
                  ),
          );
        },
      ),
    );
  }
}
