import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/read/providers/sixty_api_provider.dart';
import 'package:torrid/features/read/widgets/common.dart';

class BaikeTab extends ConsumerStatefulWidget {
  const BaikeTab({super.key});
  @override
  ConsumerState<BaikeTab> createState() => _BaikeTabState();
}

class _BaikeTabState extends ConsumerState<BaikeTab> {
  final _ctrl = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SectionTitle(title: '百度百科词条', icon: Icons.book),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  decoration: const InputDecoration(hintText: '输入关键词，例如：西游记'),
                  onSubmitted: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () {
                  setState(() {});
                  ref.invalidate(baikeEntryProvider(_ctrl.text.trim()));
                },
                icon: const Icon(Icons.search),
                label: const Text('检索'),
              ),
            ],
          ),
        ),
        if (_ctrl.text.trim().isNotEmpty)
          Consumer(builder: (context, ref, _) {
            final async = ref.watch(baikeEntryProvider(_ctrl.text.trim()));
            return async.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView('百科检索失败：$e'),
              data: (data) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (data['cover'] != null)
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Image.network(data['cover'] as String, fit: BoxFit.cover),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(data['title'] ?? '', style: Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 8),
                              if ((data['abstract'] ?? '').toString().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(data['abstract'] as String, style: Theme.of(context).textTheme.bodyMedium),
                                ),
                              Text(data['description'] ?? '', style: Theme.of(context).textTheme.bodyMedium),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: () => Clipboard.setData(ClipboardData(text: (data['link'] ?? '') as String)),
                                icon: const Icon(Icons.link),
                                label: const Text('复制百科链接'),
                              ),
                            ],
                          ),
                        ),
                      ],
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
