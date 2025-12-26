import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/read/providers/sixty_api_provider.dart';
import 'package:torrid/features/read/widgets/common.dart';

class HotlistsView extends ConsumerWidget {
  const HotlistsView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: '懂车帝热搜'),
              Tab(text: '猫眼电影实时'),
              Tab(text: '电视收视排行'),
              Tab(text: '网剧实时热度'),
              Tab(text: '全球票房总榜'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _DongchediTab(),
                _MaoyanRealtimeMovieTab(),
                _MaoyanRealtimeTvTab(),
                _MaoyanRealtimeWebTab(),
                _MaoyanAllBoxTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DongchediTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dongchediHotProvider);
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView('懂车帝热搜加载失败：$e'),
      data: (list) {
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(dongchediHotProvider),
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (ctx, i) {
              final item = list[i] as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${item['rank']}')),
                    title: Text(item['title'] ?? ''),
                    subtitle: Text('热度：${item['score_desc'] ?? ''}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () => Clipboard.setData(ClipboardData(text: (item['url'] ?? '') as String)),
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

class _MaoyanRealtimeMovieTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(maoyanRealtimeMovieProvider);
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView('猫眼电影实时票房加载失败：$e'),
      data: (data) {
        final list = (data['list'] as List<dynamic>?) ?? [];
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(maoyanRealtimeMovieProvider),
          child: ListView(
            children: [
              const SectionTitle(title: '实时大盘', icon: Icons.leaderboard),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _chip(context, '票房', '${data['box_office'] ?? ''}${data['box_office_unit'] ?? ''}'),
                    _chip(context, '人次', data['view_count_desc'] ?? ''),
                    _chip(context, '场次', data['show_count_desc'] ?? ''),
                    _chip(context, '更新时间', data['updated'] ?? ''),
                  ],
                ),
              ),
              const SectionTitle(title: '影片榜单', icon: Icons.movie),
              ...list.map((e) {
                final m = e as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Card(
                    child: ListTile(
                      title: Text(m['movie_name'] ?? ''),
                      subtitle: Text('${m['release_info'] ?? ''} · 票房 ${m['box_office_desc'] ?? ''}'),
                      trailing: Text(m['box_office_rate'] ?? ''),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _chip(BuildContext ctx, String label, String value) {
    return Chip(label: Text('$label：$value'));
  }
}

class _MaoyanRealtimeTvTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(maoyanRealtimeTvProvider);
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView('电视收视排行加载失败：$e'),
      data: (data) {
        final list = (data['list'] as List<dynamic>?) ?? [];
        final updated = data['updated'] ?? '';
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(maoyanRealtimeTvProvider),
          child: ListView.builder(
            itemCount: list.length + 1,
            itemBuilder: (ctx, i) {
              if (i == 0) {
                return SectionTitle(title: '更新时间：$updated', icon: Icons.schedule);
              }
              final item = list[i - 1] as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Card(
                  child: ListTile(
                    title: Text(item['programme_name'] ?? ''),
                    subtitle: Text(item['channel_name'] ?? ''),
                    trailing: Text(item['market_rate_desc'] ?? ''),
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

class _MaoyanRealtimeWebTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(maoyanRealtimeWebProvider);
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView('网剧实时热度加载失败：$e'),
      data: (data) {
        final list = (data['list'] as List<dynamic>?) ?? [];
        final updated = data['updated'] ?? '';
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(maoyanRealtimeWebProvider),
          child: ListView.builder(
            itemCount: list.length + 1,
            itemBuilder: (ctx, i) {
              if (i == 0) {
                return SectionTitle(title: '更新时间：$updated', icon: Icons.schedule);
              }
              final item = list[i - 1] as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Card(
                  child: ListTile(
                    title: Text(item['series_name'] ?? ''),
                    subtitle: Text(item['platform_desc'] ?? ''),
                    trailing: Text(item['curr_heat_desc'] ?? ''),
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

class _MaoyanAllBoxTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(maoyanAllBoxOfficeProvider);
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView('全球票房总榜加载失败：$e'),
      data: (data) {
        final list = (data['list'] as List<dynamic>?) ?? [];
        final tip = data['tip'] ?? '';
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(maoyanAllBoxOfficeProvider),
          child: ListView(
            children: [
              if (tip.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(tip, style: Theme.of(context).textTheme.bodySmall),
                ),
              ...list.map((e) {
                final m = e as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Text('${m['rank']}')),
                      title: Text(m['movie_name'] ?? ''),
                      subtitle: Text('年份：${m['release_year'] ?? ''}'),
                      trailing: Text(m['box_office_desc'] ?? ''),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
