import 'package:flutter/material.dart';
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
      error: (e, _) => ErrorView(
        '知乎热榜加载失败：$e',
        onRetry: () => ref.invalidate(zhihuHotProvider),
      ),
      data: (list) {
        if (list.isEmpty) {
          return ErrorView(
            '暂无知乎热榜',
            onRetry: () => ref.invalidate(zhihuHotProvider),
          );
        }
        return RefreshIndicator(
          onRefresh: () =>
              waitForFeedRefresh(ref.refresh(zhihuHotProvider.future)),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: list.length,
            itemBuilder: (ctx, i) {
              final m = list[i];
              final title = feedText(m['title']) ?? '未命名话题';
              final detail = feedText(m['detail']);
              final cover = feedUri(m['cover'])?.toString() ?? '';
              final hotDesc = feedText(m['hot_value_desc']);
              final created = feedText(m['created']);
              final link = feedUri(m['link']) ?? feedUri(m['url']);
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
                              Text(
                                title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (detail != null) ...[
                                const SizedBox(height: AppSpacing.xs),
                                Text(detail),
                              ],
                              if (hotDesc != null) ...[
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  '热度：$hotDesc',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                              if (created != null) ...[
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  '时间：$created',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
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
                            if (link != null)
                              IconButton(
                                tooltip: '打开链接',
                                icon: const Icon(Icons.open_in_new),
                                onPressed: () => openFeedLink(context, link),
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
