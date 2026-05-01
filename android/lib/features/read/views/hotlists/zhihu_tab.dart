import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/read/providers/sixty_api_provider.dart';
import 'package:torrid/features/read/widgets/common.dart';
import 'package:torrid/features/read/widgets/indexed_preview_image.dart';
import 'package:torrid/core/constants/spacing.dart';

class ZhihuTab extends ConsumerWidget {
  const ZhihuTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(zhihuHotProvider);
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorWithRetryView(
        message: '知乎热榜加载失败：$e',
        onRetry: () => ref.invalidate(zhihuHotProvider),
      ),
      data: (data) {
        final list = (data is List)
            ? data
            : ((data['list'] as List<dynamic>?) ?? []);
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(zhihuHotProvider),
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (ctx, i) {
              final m = list[i] as Map<String, dynamic>;
              final title = (m['title'] ?? '') as String;
              final detail = (m['detail'] ?? '') as String;
              final cover = (m['cover'] ?? '') as String;
              final hotDesc = (m['hot_value_desc'] ?? '') as String;
              final created = (m['created'] ?? '') as String;
              final link = (m['link']) as String?;
              final index = i + 1;
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: Theme.of(context).textTheme.titleMedium),
                              if (detail.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.xs),
                                Text(detail),
                              ],
                              const SizedBox(height: AppSpacing.xs),
                              Text('热度：$hotDesc', style: Theme.of(context).textTheme.bodySmall),
                              if (created.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.xs),
                                Text('时间：$created', style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            IndexedPreviewImage(
                              imageUrl: cover,
                              index: index,
                              width: 72,
                              height: 72,
                              radius: 8,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            IconButton(
                              tooltip: '打开链接',
                              icon: const Icon(Icons.open_in_new),
                              onPressed: () async {
                                if (link == null || link.isEmpty) return;
                                final uri = Uri.parse(link);
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
