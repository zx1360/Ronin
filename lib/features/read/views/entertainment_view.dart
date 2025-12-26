import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/read/providers/sixty_api_provider.dart';
import 'package:torrid/features/read/widgets/common.dart';

class EntertainmentView extends ConsumerWidget {
  const EntertainmentView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 6,
      child: Column(
        children: [
          const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: '随机唱歌音频'),
              Tab(text: '随机一言'),
              Tab(text: '随机段子'),
              Tab(text: '发病文学'),
              Tab(text: 'KFC 文案'),
              Tab(text: '冷笑话'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _ChangyaTab(),
                _HitokotoTab(),
                _DuanziTab(),
                _FabingTab(),
                _KFCTab(),
                _DadJokeTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangyaTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(changyaAudioProvider);
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView('随机唱歌音频加载失败：$e'),
      data: (data) {
        final user = (data['user'] as Map<String, dynamic>?);
        final song = (data['song'] as Map<String, dynamic>?);
        final audio = (data['audio'] as Map<String, dynamic>?);
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(changyaAudioProvider),
          child: ListView(
            children: [
              const SectionTitle(title: '用户与歌曲', icon: Icons.person),
              if (user != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundImage: user['avatar_url'] != null ? NetworkImage(user['avatar_url']) : null,
                      ),
                      const SizedBox(width: 12),
                      Text(user['nickname'] ?? ''),
                    ],
                  ),
                ),
              if (song != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Card(
                    child: ListTile(
                      title: Text(song['name'] ?? ''),
                      subtitle: Text(song['singer'] ?? ''),
                    ),
                  ),
                ),
              const SectionTitle(title: '音频'),
              if (audio != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.audiotrack),
                      title: Text('${audio['duration'] ?? 0} ms · ❤ ${audio['like_count'] ?? 0}'),
                      subtitle: Text(audio['url'] ?? ''),
                      trailing: IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () => Clipboard.setData(ClipboardData(text: (audio['url'] ?? '') as String)),
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
}

class _HitokotoTab extends ConsumerWidget {
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

class _DuanziTab extends ConsumerWidget {
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

class _FabingTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_FabingTab> createState() => _FabingTabState();
}

class _FabingTabState extends ConsumerState<_FabingTab> {
  final _nameCtrl = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final name = _nameCtrl.text.trim();
    final async = ref.watch(fabingProvider(name.isEmpty ? null : name));
    return ListView(
      children: [
        const SectionTitle(title: '随机发病文学', icon: Icons.auto_stories),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(hintText: '替换的人名（可选），默认：主人'),
                  onSubmitted: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => setState(() {}),
                child: const Text('生成'),
              ),
            ],
          ),
        ),
        async.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView('生成失败：$e'),
          data: (data) => Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(data['saying'] ?? ''),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _KFCTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(kfcCopyProvider);
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView('KFC 文案加载失败：$e'),
      data: (data) {
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(kfcCopyProvider),
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(data['kfc'] ?? ''),
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

class _DadJokeTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dadJokeProvider);
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView('冷笑话加载失败：$e'),
      data: (data) {
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(dadJokeProvider),
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(data['content'] ?? ''),
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
