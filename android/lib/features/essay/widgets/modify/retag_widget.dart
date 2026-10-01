import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/essay/providers/essay_notifier_provider.dart';
import 'package:torrid/features/essay/providers/setting_provider.dart';
import 'package:torrid/features/essay/providers/status_provider.dart';
import 'package:torrid/features/essay/widgets/label_selector.dart';

class RetagWidget extends ConsumerWidget {
  const RetagWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labels = ref.watch(labelsProvider);
    final essay = ref.watch(contentServerProvider);
    if (essay == null) return const SizedBox.shrink();

    final selectedLabels = labels
        .where((l) => essay.labels.contains(l.id))
        .map((l) => l.id)
        .toList();

    void onToggle(String labelId) {
      ref.read(essayServiceProvider.notifier).retag(essay.id, labelId);
    }

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

          TextButton.icon(
            icon: const Icon(Icons.title),
            label: const Text('编辑标题（可选）'),
            onPressed: () async {
              var titleText = essay.title;
              final title = await showDialog<String>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('随笔标题'),
                  content: TextFormField(
                    initialValue: titleText,
                    onChanged: (value) => titleText = value,
                    maxLength: 100,
                    decoration: const InputDecoration(hintText: '留空时继续展示日期与正文'),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, titleText.trim()),
                      child: const Text('保存'),
                    ),
                  ],
                ),
              );
              if (title == null || !context.mounted) return;
              try {
                await ref
                    .read(essayServiceProvider.notifier)
                    .writeEssay(essay: essay.copyWith(title: title));
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('$e')));
                }
              }
            },
          ),

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
