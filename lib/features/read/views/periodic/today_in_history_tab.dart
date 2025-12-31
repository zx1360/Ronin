import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/read/providers/sixty_api_provider.dart';
import 'package:torrid/features/read/widgets/common.dart';
import 'package:torrid/core/constants/spacing.dart';

class TodayInHistoryTab extends ConsumerWidget {
  const TodayInHistoryTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(todayInHistoryProvider(null));
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView('历史上的今天加载失败：$e'),
      data: (data) {
        final items = (data['items'] as List<dynamic>?) ?? [];
        final date = data['date'] ?? '';
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(todayInHistoryProvider(null));
          },
          child: ListView.builder(
            itemCount: items.length + 1,
            itemBuilder: (ctx, i) {
              if (i == 0) {
                return SectionTitle(title: '日期：$date', icon: Icons.event);
              }
              final item = items[i - 1] as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: Card(
                  child: ListTile(
                    title: Text(
                      '${item['year'] ?? ''} · ${item['title'] ?? ''}',
                    ),
                    subtitle: Text(item['description'] ?? ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () => Clipboard.setData(
                        ClipboardData(text: (item['link'] ?? '') as String),
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
