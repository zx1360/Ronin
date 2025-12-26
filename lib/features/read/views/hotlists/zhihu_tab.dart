import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/read/providers/sixty_api_provider.dart';
import 'package:torrid/features/read/widgets/common.dart';

class ZhihuTab extends ConsumerWidget {
  const ZhihuTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(zhihuHotProvider);
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView('知乎热榜加载失败：$e'),
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
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${i + 1}')),
                    title: Text(m['title'] ?? ''),
                    subtitle: Text('热度：${m['hot'] ?? m['heat'] ?? ''}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () => Clipboard.setData(ClipboardData(text: (m['url'] ?? m['link'] ?? '') as String)),
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
