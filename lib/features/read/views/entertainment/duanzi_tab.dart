import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/read/providers/sixty_api_provider.dart';
import 'package:torrid/features/read/widgets/common.dart';

class DuanziTab extends ConsumerWidget {
  const DuanziTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(duanziProvider);
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView('随机段子加载失败：$e'),
      data: (data) {
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(duanziProvider),
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(data['duanzi'] ?? ''),
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
