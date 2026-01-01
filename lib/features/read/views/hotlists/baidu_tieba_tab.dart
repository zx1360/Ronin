import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/read/providers/sixty_api_provider.dart';
import 'package:torrid/features/read/widgets/common.dart';
import 'package:torrid/core/constants/spacing.dart';

class BaiduTiebaTab extends ConsumerWidget {
  const BaiduTiebaTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(baiduTiebaProvider);
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorWithRetryView(
        message: '百度贴吧榜加载失败：$e',
        onRetry: () => ref.invalidate(baiduTiebaProvider),
      ),
      data: (data) {
        final list = (data is List)
            ? data
            : ((data['list'] as List<dynamic>?) ?? []);
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(baiduTiebaProvider),
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (ctx, i) {
              final m = list[i] as Map<String, dynamic>;
              final title = m['title'] as String;
              final desc = (m['desc'] ?? '') as String;
              final abstractText = (m['abstract'] ?? '') as String;
              final heatDesc = (m['score_desc'] ?? '') as String;
              final url = (m['url'] ?? m['link']) as String?;
              final rank = i + 1;
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
                        CircleAvatar(child: Text('$rank')),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: Theme.of(context).textTheme.titleMedium),
                              if (desc.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.xs),
                                Text(desc),
                              ],
                              if (abstractText.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.xs),
                                Text(abstractText, style: Theme.of(context).textTheme.bodySmall),
                              ],
                              const SizedBox(height: AppSpacing.xs),
                              Text('热度：$heatDesc', style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: '打开链接',
                          icon: const Icon(Icons.open_in_new),
                          onPressed: () async {
                            if (url == null || url.isEmpty) return;
                            final uri = Uri.parse(url);
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          },
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
