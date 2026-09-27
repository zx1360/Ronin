import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:torrid/features/read/providers/sixty_api_provider.dart';
import 'package:torrid/features/read/widgets/common.dart';
import 'package:torrid/core/constants/spacing.dart';

class SentenceTab extends ConsumerWidget {
  const SentenceTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      children: [
        const SectionTitle(title: '随机一言'),
        _sectionCard(
          context,
          async: ref.watch(hitokotoProvider),
          contentSelector: (m) => (m['hitokoto'] ?? '') as String,
          onRefresh: () => ref.invalidate(hitokotoProvider),
        ),

        const SectionTitle(title: '随机段子'),
        _sectionCard(
          context,
          async: ref.watch(duanziProvider),
          contentSelector: (m) => (m['duanzi'] ?? '') as String,
          onRefresh: () => ref.invalidate(duanziProvider),
        ),

        const SectionTitle(title: '发病文学'),
        _sectionCard(
          context,
          async: ref.watch(fabingProvider(null)),
          contentSelector: (m) => (m['saying'] ?? '') as String,
          onRefresh: () => ref.invalidate(fabingProvider(null)),
        ),

        const SectionTitle(title: 'KFC 文案'),
        _sectionCard(
          context,
          async: ref.watch(kfcCopyProvider),
          contentSelector: (m) => (m['kfc'] ?? '') as String,
          onRefresh: () => ref.invalidate(kfcCopyProvider),
        ),

        const SectionTitle(title: '冷笑话'),
        _sectionCard(
          context,
          async: ref.watch(dadJokeProvider),
          contentSelector: (m) => (m['content'] ?? '') as String,
          onRefresh: () => ref.invalidate(dadJokeProvider),
        ),

        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  Widget _sectionCard(
    BuildContext context, {
    required AsyncValue<Map<String, dynamic>> async,
    required String Function(Map<String, dynamic>) contentSelector,
    required void Function() onRefresh,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView('加载失败：$e'),
        data: (m) {
          final content = contentSelector(m);
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(content),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: onRefresh,
                        icon: const Icon(Icons.refresh),
                        label: const Text('刷新'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () =>
                            Clipboard.setData(ClipboardData(text: content)),
                        icon: const Icon(Icons.copy),
                        label: const Text('复制'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
