import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:northstar/app/theme.dart';
import 'package:northstar/core/providers/ai/ai_providers.dart';
import 'package:northstar/core/providers/ops/ops_settings_provider.dart';
import 'package:northstar/domain/ai/models/ai_models.dart';

/// 近重复分组（pHash）：计算开销较大，按需触发。
class AiDuplicatesTab extends ConsumerStatefulWidget {
  const AiDuplicatesTab({super.key});

  @override
  ConsumerState<AiDuplicatesTab> createState() => _AiDuplicatesTabState();
}

class _AiDuplicatesTabState extends ConsumerState<AiDuplicatesTab> {
  bool _requested = false;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(opsSettingsControllerProvider);
    final client = ref.read(aiApiClientProvider);

    return Padding(
      padding: const EdgeInsets.all(AppDimens.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => _requested = true);
                  ref.invalidate(aiDuplicatesProvider);
                },
                icon: const Icon(Icons.filter_none_rounded, size: 16),
                label: Text(_requested ? '重新计算' : '计算近重复分组'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '基于 pHash 感知哈希：汉明距离 ≤ 4 的图片会被归为一组，'
            '可识别同一张图的缩放、转码、加水印等变体。'
            '仅展示分组，不会自动删除任何文件 —— 删除请走画廊原有的软删除流程。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppDimens.spacingS),
          Expanded(
            child: !_requested
                ? const Center(child: Text('点击上方按钮开始计算'))
                : ref.watch(aiDuplicatesProvider).when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, _) => Center(
                        child: Text(
                          error.toString(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                      data: (groups) {
                        if (groups.isEmpty) {
                          return const Center(child: Text('未发现近重复图片'));
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('共 ${groups.length} 组',
                                style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(height: AppDimens.spacingXS),
                            Expanded(
                              child: ListView.separated(
                                itemCount: groups.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) => _GroupCard(
                                  group: groups[index],
                                  thumbUrlOf: (mediaId) =>
                                      client.thumbUrl(settings, mediaId),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final AiDuplicateGroup group;
  final String Function(String mediaId) thumbUrlOf;

  const _GroupCard({required this.group, required this.thumbUrlOf});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.paddingS),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${group.mediaIds.length} 张 · 最大差异 ${group.distance} 位',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: group.mediaIds.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final mediaId = group.mediaIds[index];
                  final file = index < group.files.length ? group.files[index] : '';
                  return Tooltip(
                    message: file,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        thumbUrlOf(mediaId),
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 96,
                          height: 96,
                          color: AppColors.surfaceVariant,
                          child: const Icon(Icons.broken_image_outlined,
                              size: 20),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
            Text(
              group.files.take(3).join('  |  '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
