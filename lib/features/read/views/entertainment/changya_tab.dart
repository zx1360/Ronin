import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:torrid/features/read/providers/sixty_api_provider.dart';
import 'package:torrid/features/read/providers/changya_local_provider.dart';
import 'package:torrid/features/read/widgets/common.dart';
import 'package:torrid/features/read/widgets/audio_player.dart';
import 'package:torrid/core/constants/spacing.dart';
import 'package:torrid/features/read/models/changya/changya_record.dart';
import 'package:torrid/features/read/views/entertainment/widgets/changya_top_bar.dart';
import 'package:torrid/features/read/views/entertainment/widgets/changya_user_line.dart';

class ChangyaTab extends ConsumerStatefulWidget {
  const ChangyaTab({super.key});
  @override
  ConsumerState<ChangyaTab> createState() => _ChangyaTabState();
}

class _ChangyaTabState extends ConsumerState<ChangyaTab> {
  bool useLocal = false; // 在线/本地切换

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (useLocal) {
      final listAsync = ref.watch(listChangyaLocalProvider);
      return listAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView('读取本地数据失败：$e'),
        data: (list) {
          if (list.isEmpty) {
            return ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              children: [
                _buildTopBar(context, ref, null, isLocal: true),
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Text('暂无本地数据，请在在线模式点击保存。'),
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            children: [
              _buildTopBar(
                context,
                ref,
                null,
                isLocal: true
              ),
              const SectionTitle(title: '本地记录', icon: Icons.download_done),
              ...list.map((r) => _buildLocalCard(context, ref, r)).toList(),
            ],
          );
        },
      );
    } else {
      final asyncOnline = ref.watch(changyaAudioProvider);
      return _buildOnlineContent(context, ref, asyncOnline);
    }
  }
  

  Widget _buildTopBar(BuildContext context, WidgetRef ref, Map<String, dynamic>? data, {required bool isLocal}) {
    final user = (data?['user'] as Map<String, dynamic>?) ?? {};
    final String? avatarUrl = (user['avatar'] ?? user['avatar_url'] ?? user['avatarUrl'])?.toString();
    final String? nickname = (user['nickname'] ?? '')?.toString();
    final String? gender = (user['gender'] ?? '-')?.toString();
    return ChangyaTopBar(
      useLocal: useLocal,
      onToggle: (v) => setState(() => useLocal = v),
      onRefresh: () {
        if (useLocal) {
          ref.invalidate(listChangyaLocalProvider);
        } else {
          ref.invalidate(changyaAudioProvider);
        }
      },
      onSave: (!isLocal && data != null)
          ? () async {
              await ref.read(saveChangyaLocalProvider(data).future);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存到本地 /changya/')));
              }
            }
          : null,
      nickname: nickname,
      gender: gender,
      avatarUrl: avatarUrl,
      showUser: (nickname?.isNotEmpty == true) || (avatarUrl?.isNotEmpty == true),
    );
  }

  Widget _buildOnlineContent(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<Map<String, dynamic>> async,
  ) {
    String msToText(dynamic ms) {
      final durMs = (ms is int) ? ms : int.tryParse('$ms') ?? 0;
      final d = Duration(milliseconds: durMs);
      String two(int n) => n.toString().padLeft(2, '0');
      return '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
    }

    final data = async.asData?.value;
    final loading = async.isLoading;
    final hasError = async.hasError;
    final error = hasError ? async.error : null;

    final song = (data?['song'] as Map<String, dynamic>?) ?? {};
    final audio = (data?['audio'] as Map<String, dynamic>?) ?? {};

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      children: [
        _buildTopBar(context, ref, data, isLocal: false),

        if (hasError && error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            child: Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Theme.of(context).colorScheme.onErrorContainer),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        '网络加载失败：$error',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onErrorContainer,
                            ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                    TextButton(
                      onPressed: () => ref.invalidate(changyaAudioProvider),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            ),
          ),

        const SectionTitle(title: '歌曲信息', icon: Icons.music_note),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          child: Card(
            child: ListTile(
              title: Text((song['name'] ?? (loading ? '加载中…' : '')).toString()),
              subtitle: Text((song['singer'] ?? (loading ? '——' : '')).toString()),
            ),
          ),
        ),
        if ((song['lyrics'] is List && (song['lyrics'] as List).isNotEmpty) || loading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('歌词', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    if (loading && (song['lyrics'] == null))
                      Text('加载中…', style: Theme.of(context).textTheme.bodyMedium)
                    else
                      ...((song['lyrics'] as List? ?? const <String>[])
                          .cast<String>()
                          .map((l) => Text(l))),
                  ],
                ),
              ),
            ),
          ),

        const SectionTitle(title: '音频', icon: Icons.audiotrack),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.speaker),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          '${msToText(audio['duration'])} · ❤ ${(audio['like_count'] ?? (loading ? 0 : 0)).toString()}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      if ((audio['link'] ?? '').toString().isNotEmpty)
                        IconButton(
                          tooltip: '打开来源',
                          onPressed: () async {
                            final link = Uri.tryParse((audio['link'] ?? '').toString());
                            if (link != null) {
                              await launchUrl(link, mode: LaunchMode.externalApplication);
                            }
                          },
                          icon: const Icon(Icons.open_in_new),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      const Icon(Icons.event),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('发布时间: ${(audio['publish'] ?? (loading ? '加载中…' : '')).toString()}'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if ((audio['url'] ?? '').toString().isNotEmpty)
                    SimpleAudioPlayer(url: (audio['url'] as String))
                  else if (loading)
                    const LinearProgressIndicator(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocalCard(BuildContext context, WidgetRef ref, ChangyaRecord r) {
    String msToText(int? ms) {
      final d = Duration(milliseconds: ms ?? 0);
      String two(int n) => n.toString().padLeft(2, '0');
      return '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((r.user?.avatarUrl ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ChangyaUserLine(
                    avatarUrl: r.user!.avatarUrl,
                    nickname: r.user?.nickname ?? '',
                    gender: r.user?.gender ?? '-',
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${r.song?.name ?? ''} · ${r.song?.singer ?? ''}',
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: '删除',
                    onPressed: () async {
                      await ref.read(deleteChangyaLocalProvider(r).future);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已删除')));
                      }
                      ref.invalidate(listChangyaLocalProvider);
                    },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  const Icon(Icons.audiotrack),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '${msToText(r.audio?.duration)} · ❤ ${r.audio?.likeCount ?? 0}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if ((r.audio?.url ?? '').isNotEmpty)
                SimpleAudioPlayer(url: r.audio!.url!),
              if (r.song?.lyrics.isNotEmpty == true) ...[
                const SizedBox(height: AppSpacing.sm),
                Text('歌词', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                ...r.song!.lyrics.map((l) => Text(l)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

