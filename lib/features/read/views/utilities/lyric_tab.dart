import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/read/providers/sixty_api_provider.dart';
import 'package:torrid/features/read/widgets/common.dart';

class LyricTab extends ConsumerStatefulWidget {
  const LyricTab({super.key});
  @override
  ConsumerState<LyricTab> createState() => _LyricTabState();
}

class _LyricTabState extends ConsumerState<LyricTab> {
  final _ctrl = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SectionTitle(title: '搜索歌词', icon: Icons.music_note),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  decoration: const InputDecoration(hintText: '输入歌曲名，例如：小宇'),
                  onSubmitted: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () {
                  setState(() {});
                  ref.invalidate(lyricSearchProvider(_ctrl.text.trim()));
                },
                icon: const Icon(Icons.search),
                label: const Text('搜索'),
              ),
            ],
          ),
        ),
        if (_ctrl.text.trim().isNotEmpty)
          Consumer(builder: (context, ref, _) {
            final async = ref.watch(lyricSearchProvider(_ctrl.text.trim()));
            return async.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView('歌词搜索失败：$e'),
              data: (data) {
                final formatted = data['formatted'] as String?;
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(
                        formatted ?? '未找到歌词',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        const SizedBox(height: 24),
      ],
    );
  }
}
