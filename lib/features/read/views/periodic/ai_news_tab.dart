import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/read/providers/sixty_api_provider.dart';
import 'package:torrid/features/read/widgets/common.dart';

class AiNewsTab extends ConsumerWidget {
  const AiNewsTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(aiNewsProvider(null));
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView('AI资讯加载失败：$e'),
      data: (data) {
        final list = (data['news'] as List<dynamic>?) ?? (data['list'] as List<dynamic>?) ?? [];
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(aiNewsProvider(null));
          },
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (ctx, i) {
              final item = list[i] as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Card(
                  child: ListTile(
                    title: Text(item['title'] ?? ''),
                    subtitle: Text(item['detail'] ?? ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () => Clipboard.setData(ClipboardData(text: (item['link'] ?? '') as String)),
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
