import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:torrid/features/read/providers/sixty_api_provider.dart';
import 'package:torrid/features/read/widgets/common.dart';
import 'package:torrid/core/constants/spacing.dart';

class AiNewsTab extends ConsumerWidget {
  const AiNewsTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(aiNewsProvider(null));
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView('AI资讯加载失败：$e'),
      data: (data) {
        final list = (data['news'] as List<dynamic>?) ?? [];
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(aiNewsProvider(null));
          },
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (ctx, i) {
              final item = list[i] as Map<String, dynamic>;
              final link = (item['link'] ?? '') as String;
              final source = (item['source'] ?? '') as String;
              final date = (item['date'] ?? '') as String;
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: Card(
                  child: InkWell(
                    onTap: () async {
                      if (link.isEmpty) return;
                      final uri = Uri.parse(link);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['title'] ?? '',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          if (((item['detail'] ?? '') as String).isNotEmpty)
                            Text(
                              item['detail'] ?? '',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          const SizedBox(height: 6),
                          if (source.isNotEmpty || date.isNotEmpty)
                            Text(
                              [
                                if (source.isNotEmpty) source,
                                if (date.isNotEmpty) date,
                              ].join(' · '),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                tooltip: '在浏览器打开',
                                icon: const Icon(Icons.open_in_new),
                                onPressed: () async {
                                  if (link.isEmpty) return;
                                  final uri = Uri.parse(link);
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(
                                      uri,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  }
                                },
                              ),
                              IconButton(
                                tooltip: '复制链接',
                                icon: const Icon(Icons.copy),
                                onPressed: () => Clipboard.setData(
                                  ClipboardData(text: link),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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
