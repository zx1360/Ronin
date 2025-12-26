import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/read/providers/sixty_api_provider.dart';
import 'package:torrid/features/read/widgets/common.dart';

class MoyuTab extends ConsumerWidget {
  const MoyuTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(moyuDailyProvider);
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView('摸鱼日报加载失败：$e'),
      data: (data) {
        final quote = data['moyuQuote'] as String?;
        final progress = data['progress'] as Map<String, dynamic>?;
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(moyuDailyProvider),
          child: ListView(
            children: [
              const SectionTitle(title: '今日进度', icon: Icons.timeline),
              if (progress != null) ...[
                _progressRow(context, '周进度', progress['week'] as Map<String, dynamic>?),
                _progressRow(context, '月进度', progress['month'] as Map<String, dynamic>?),
                _progressRow(context, '年进度', progress['year'] as Map<String, dynamic>?),
              ],
              const SectionTitle(title: '摸鱼金句', icon: Icons.format_quote),
              if (quote != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: ListTile(
                      title: Text(quote),
                      trailing: IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () => Clipboard.setData(ClipboardData(text: quote)),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _progressRow(BuildContext context, String label, Map<String, dynamic>? p) {
    if (p == null) return const SizedBox.shrink();
    final percent = ((p['percentage'] ?? 0) as num).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: percent / 100),
          const SizedBox(height: 4),
          Text('已完成：${percent.toStringAsFixed(0)}%'),
        ],
      ),
    );
  }
}
