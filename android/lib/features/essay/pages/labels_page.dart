import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/core/modals/confirm_modal.dart';
import 'package:torrid/features/essay/providers/essay_notifier_provider.dart';
import 'package:torrid/features/essay/providers/status_provider.dart';
import 'package:torrid/features/essay/widgets/label_editor.dart';
import 'package:torrid/features/essay/widgets/label_selector.dart';

class EssayLabelsPage extends ConsumerWidget {
  const EssayLabelsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labels = ref.watch(labelsProvider);
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
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${labels.length} 个标签 · 箭头展开层级，点击名称编辑',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: LabelSelector(
                  labels: labels,
                  selectedLabels: const [],
                  onToggleLabel: (id) {
                    final label = labels.firstWhere((l) => l.id == id);
                    if (!label.isHiddenRoot) {
                      showLabelEditor(context, ref, label: label);
                    }
                  },
                  trailingBuilder: (label) => PopupMenuButton<String>(
                    tooltip: '标签操作',
                    itemBuilder: (_) => [
                      if (!label.isHiddenRoot)
                        const PopupMenuItem(value: 'edit', child: Text('编辑标签')),
                      const PopupMenuItem(value: 'add', child: Text('添加子标签')),
                      if (!label.isHiddenRoot)
                        PopupMenuItem(
                          value: 'delete',
                          enabled:
                              label.essayCount == 0 &&
                              !labels.any((l) => l.parentId == label.id),
                          child: const Text('删除未使用标签'),
                        ),
                    ],
                    onSelected: (action) {
                      if (action == 'edit') {
                        showLabelEditor(context, ref, label: label);
                      } else if (action == 'add') {
                        showLabelEditor(context, ref, parentId: label.id);
                      } else {
                        showConfirmDialog(
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
                        );
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
