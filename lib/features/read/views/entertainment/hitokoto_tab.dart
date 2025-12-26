import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/read/providers/sixty_api_provider.dart';
import 'package:torrid/features/read/widgets/common.dart';

class HitokotoTab extends ConsumerWidget {
  const HitokotoTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(hitokotoProvider);
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView('随机一言加载失败：$e'),
      data: (data) {
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(hitokotoProvider),
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: ListTile(
                    title: Text(data['hitokoto'] ?? ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () => Clipboard.setData(ClipboardData(text: (data['hitokoto'] ?? '') as String)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
