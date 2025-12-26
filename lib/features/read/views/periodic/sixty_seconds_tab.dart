import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/read/providers/sixty_api_provider.dart';
import 'package:torrid/features/read/widgets/common.dart';
import 'package:torrid/features/read/widgets/image_preview.dart';

class SixtySecondsTab extends ConsumerWidget {
  const SixtySecondsTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sixtySecondsProvider(null));
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView('60秒读懂世界加载失败：$e'),
      data: (data) {
        final news = (data['news'] as List<dynamic>?) ?? [];
        final image = data['image'] as String?;
        final tip = data['tip'] as String?;
        final link = data['link'] as String?;
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(sixtySecondsProvider(null));
          },
          child: ListView(
            children: [
              const SectionTitle(title: '封面'),
              if (image != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Image.network(image, fit: BoxFit.cover),
                        ),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: FilledButton.icon(
                            onPressed: () => showImagePreview(context, image),
                            icon: const Icon(Icons.fullscreen),
                            label: const Text('查看大图'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SectionTitle(title: '要闻'),
              ...news.map((n) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          n.toString(),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  )),
              if (tip != null) const SectionTitle(title: 'Tip'),
              if (tip != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.lightbulb),
                      title: Text(tip),
                      trailing: IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () => Clipboard.setData(ClipboardData(text: tip)),
                      ),
                    ),
                  ),
                ),
              if (link != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: OutlinedButton.icon(
                    onPressed: () => Clipboard.setData(ClipboardData(text: link)),
                    icon: const Icon(Icons.link),
                    label: const Text('复制原文链接'),
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
