import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/read/providers/sixty_api_provider.dart';
import 'package:torrid/features/read/widgets/common.dart';
import 'package:torrid/features/read/widgets/image_preview.dart';

class PeriodicView extends ConsumerWidget {
  const PeriodicView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: '60秒读懂世界'),
              Tab(text: 'AI资讯快报'),
              Tab(text: '必应每日壁纸'),
              Tab(text: '历史上的今天'),
              Tab(text: 'Epic 免费游戏'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _SixtySecondsTab(),
                _AiNewsTab(),
                _BingWallpaperTab(),
                _TodayInHistoryTab(),
                _EpicGamesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SixtySecondsTab extends ConsumerWidget {
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
            ref.invalidate(sixtySecondsProvider);
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

class _AiNewsTab extends ConsumerWidget {
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
            ref.invalidate(aiNewsProvider);
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

class _BingWallpaperTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(bingWallpaperProvider);
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView('必应壁纸加载失败：$e'),
      data: (data) {
        final cover = data['cover'] as String?;
        final cover4k = data['cover_4k'] as String?;
        final title = data['title'] as String?;
        final desc = data['description'] as String?;
        final mainText = data['main_text'] as String?;
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(bingWallpaperProvider);
          },
          child: ListView(
            children: [
              if (title != null) SectionTitle(title: title, icon: Icons.image),
              if (cover != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: GestureDetector(
                      onTap: () => showImagePreview(context, cover),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(cover, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
              if (cover4k != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: FilledButton.icon(
                    onPressed: () => showImagePreview(context, cover4k),
                    icon: const Icon(Icons.hd),
                    label: const Text('查看 4K'),
                  ),
                ),
              if (desc != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(desc, style: Theme.of(context).textTheme.bodyLarge),
                ),
              if (mainText != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Text(mainText, style: Theme.of(context).textTheme.bodyMedium),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TodayInHistoryTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(todayInHistoryProvider);
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView('历史上的今天加载失败：$e'),
      data: (data) {
        final items = (data['items'] as List<dynamic>?) ?? [];
        final date = data['date'] ?? '';
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(todayInHistoryProvider);
          },
          child: ListView.builder(
            itemCount: items.length + 1,
            itemBuilder: (ctx, i) {
              if (i == 0) {
                return SectionTitle(title: '日期：$date', icon: Icons.event);
              }
              final item = items[i - 1] as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Card(
                  child: ListTile(
                    title: Text('${item['year'] ?? ''} · ${item['title'] ?? ''}'),
                    subtitle: Text(item['description'] ?? ''),
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

class _EpicGamesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(epicGamesProvider);
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView('Epic 免费游戏加载失败：$e'),
      data: (list) {
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(epicGamesProvider);
          },
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (ctx, i) {
              final item = list[i] as Map<String, dynamic>;
              final isFree = item['is_free_now'] == true;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Image.network(item['cover'] ?? '', fit: BoxFit.cover),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['title'] ?? '', style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 8),
                            Text(item['description'] ?? '', style: Theme.of(context).textTheme.bodyMedium),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Chip(
                                  label: Text(isFree ? '当前免费' : '非免费'),
                                  avatar: Icon(isFree ? Icons.card_giftcard : Icons.money_off),
                                ),
                                const SizedBox(width: 12),
                                Text('原价：${item['original_price_desc'] ?? ''}'),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => Clipboard.setData(ClipboardData(text: (item['link'] ?? '') as String)),
                                  icon: const Icon(Icons.link),
                                  label: const Text('复制商店链接'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
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
