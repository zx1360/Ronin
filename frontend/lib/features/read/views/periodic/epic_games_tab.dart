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
      error: (e, _) => ErrorView('Epic 免费游戏加载失败：$e'),
      data: (list) {
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(epicGamesProvider);
          },
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (ctx, i) {
              final item = list[i] as Map<String, dynamic>;
              final isFree = item['is_free_now'] == true;
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Image.network(
                            item['cover'] ?? '',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['title'] ?? '',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item['description'] ?? '',
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
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => Clipboard.setData(
                                    ClipboardData(
                                      text: (item['link'] ?? '') as String,
                                    ),
                                  ),
                                  icon: const Icon(Icons.link),
                                  label: const Text('复制商店链接'),
                                ),
                              ],
                            ),
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
