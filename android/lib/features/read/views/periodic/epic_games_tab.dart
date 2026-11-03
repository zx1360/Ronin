import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/read/providers/sixty_api_provider.dart';
import 'package:torrid/features/read/widgets/common.dart';
import 'package:torrid/core/constants/spacing.dart';

class EpicGamesTab extends ConsumerWidget {
  const EpicGamesTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(epicGamesProvider);
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(
        'Epic 免费游戏加载失败：$e',
        onRetry: () => ref.invalidate(epicGamesProvider),
      ),
      data: (list) {
        if (list.isEmpty) {
          return ErrorView(
            '暂无免费游戏信息',
            onRetry: () => ref.invalidate(epicGamesProvider),
          );
        }
        return RefreshIndicator(
          onRefresh: () =>
              waitForFeedRefresh(ref.refresh(epicGamesProvider.future)),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: list.length,
            itemBuilder: (ctx, i) {
              final item = list[i];
              final isFree = item['is_free_now'] == true;
              final cover = feedUri(item['cover'])?.toString();
              final link = feedUri(item['link'])?.toString();
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (cover != null)
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Image.network(
                              cover,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const Center(child: Text('封面暂时无法加载')),
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              feedText(item['title']) ?? '未命名游戏',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              feedText(item['description']) ?? '',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Chip(
                                  label: Text(isFree ? '当前免费' : '非免费'),
                                  avatar: Icon(
                                    isFree
                                        ? Icons.card_giftcard
                                        : Icons.money_off,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text('原价：${item['original_price_desc'] ?? ''}'),
                              ],
                            ),
                            if (link != null) ...[
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: () => Clipboard.setData(
                                  ClipboardData(text: link),
                                ),
                                icon: const Icon(Icons.link),
                                label: const Text('复制商店链接'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
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
