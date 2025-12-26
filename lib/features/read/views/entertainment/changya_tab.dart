import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/read/providers/sixty_api_provider.dart';
import 'package:torrid/features/read/widgets/common.dart';
import 'package:torrid/features/read/widgets/audio_player.dart';

class ChangyaTab extends ConsumerWidget {
  const ChangyaTab({super.key});
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
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.audiotrack),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${audio['duration'] ?? 0} ms · ❤ ${audio['like_count'] ?? 0}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy),
                                onPressed: () => Clipboard.setData(ClipboardData(text: (audio['url'] ?? '') as String)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if ((audio['url'] ?? '').toString().isNotEmpty)
                            SimpleAudioPlayer(url: (audio['url'] as String)),
                        ],
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
