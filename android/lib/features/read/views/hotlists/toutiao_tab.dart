import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/read/providers/sixty_api_provider.dart';
import 'package:torrid/features/read/widgets/common.dart';
import 'package:torrid/features/read/widgets/indexed_preview_image.dart';
import 'package:torrid/core/constants/spacing.dart';

class ToutiaoTab extends ConsumerWidget {
  const ToutiaoTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(toutiaoHotProvider);
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(
        '头条热榜加载失败：$e',
        onRetry: () => ref.invalidate(toutiaoHotProvider),
      ),
      data: (list) {
        if (list.isEmpty) {
          return ErrorView(
            '暂无头条热榜',
            onRetry: () => ref.invalidate(toutiaoHotProvider),
          );
        }
        return RefreshIndicator(
          onRefresh: () =>
              waitForFeedRefresh(ref.refresh(toutiaoHotProvider.future)),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: list.length,
            itemBuilder: (ctx, i) {
              final m = list[i];
              final title = feedText(m['title']) ?? '未命名话题';
              final hotValue = m['hot_value'];
              final cover = feedUri(m['cover'])?.toString() ?? '';
              final link = feedUri(m['link']) ?? feedUri(m['url']);
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
                        IndexedPreviewImage(
                          imageUrl: cover,
                          index: i + 1,
                          width: 64,
                          height: 64,
                          radius: 8,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (hotValue != null) ...[
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  '热度：$hotValue',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (link != null)
                          IconButton(
                            tooltip: '打开链接',
                            icon: const Icon(Icons.open_in_new),
                            onPressed: () => openFeedLink(context, link),
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
