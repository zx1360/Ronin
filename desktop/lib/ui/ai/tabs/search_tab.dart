import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:northstar/app/theme.dart';
import 'package:northstar/core/providers/ai/ai_providers.dart';
import 'package:northstar/core/providers/ops/ops_settings_provider.dart';
import 'package:northstar/domain/ai/models/ai_models.dart';
import 'package:northstar/ui/ai/widgets/ai_widgets.dart';

/// 智能检索：文本搜图（语义/关键词/混合）与以图搜图。
class AiSearchTab extends ConsumerStatefulWidget {
  const AiSearchTab({super.key});

  @override
  ConsumerState<AiSearchTab> createState() => _AiSearchTabState();
}

class _AiSearchTabState extends ConsumerState<AiSearchTab> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiSearchProvider);
    final notifier = ref.read(aiSearchProvider.notifier);
    final settings = ref.watch(opsSettingsControllerProvider);
    final client = ref.read(aiApiClientProvider);

    return Padding(
      padding: const EdgeInsets.all(AppDimens.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (value) => notifier.search(value),
                  decoration: InputDecoration(
                    hintText: state.mode == 'filename'
                        ? '文件名或扩展名，例如：IMG_2024、.mp4'
                        : '用自然语言描述想要的画面，例如：可爱的猫娘、夜景街道',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _controller.clear();
                        notifier.clear();
                      },
                    ),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.spacingS),
              DropdownButton<String>(
                value: state.mode,
                isDense: true,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'auto', child: Text('智能')),
                  DropdownMenuItem(value: 'keyword', child: Text('文字')),
                  DropdownMenuItem(value: 'filename', child: Text('文件名')),
                ],
                onChanged: (value) {
                  if (value != null) notifier.setMode(value);
                },
              ),
              const SizedBox(width: AppDimens.spacingS),
              ElevatedButton.icon(
                onPressed: state.loading
                    ? null
                    : () => notifier.search(_controller.text),
                icon: const Icon(Icons.search_rounded, size: 16),
                label: const Text('搜索'),
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
            '智能模式：有文本就走语义检索（SigLIP 向量），并把 OCR/描述/关键词命中一并加权；'
            '文字模式只在 OCR/描述/AI 关键词里找；文件名模式只匹配文件路径，可用扩展名过滤。'
            '点击结果卡片上的"以图搜图"可找相似画面。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppDimens.spacingS),
          if (state.error != null)
            Text(
              state.error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          if (state.loading) const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: AppDimens.spacingS),
          Expanded(
            child: state.isEmpty
                ? const Center(child: Text('输入关键词开始检索'))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '命中 ${state.result.total} 条 · 模式 ${state.result.mode}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppDimens.spacingXS),
                      Expanded(
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 170,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.8,
                          ),
                          itemCount: state.result.hits.length,
                          itemBuilder: (context, index) {
                            final hit = state.result.hits[index];
                            return _HitCard(
                              hit: hit,
                              thumbUrl: client.thumbUrl(settings, hit.id),
                              onSimilar: () => notifier.similarTo(hit.id),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _HitCard extends StatelessWidget {
  final AiSearchHit hit;
  final String thumbUrl;
  final VoidCallback onSimilar;

  const _HitCard({
    required this.hit,
    required this.thumbUrl,
    required this.onSimilar,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  thumbUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const ColoredBox(
                    color: AppColors.surfaceVariant,
                    child: Icon(Icons.broken_image_outlined, size: 24),
                  ),
                ),
                if (hit.source.contains('semantic'))
                  const Positioned(
                    top: 4,
                    left: 4,
                    child: AiStatusPill(text: '语义', color: AppColors.info),
                  ),
                if (hit.source.contains('keyword'))
                  const Positioned(
                    top: 4,
                    right: 4,
                    child: AiStatusPill(text: '文本', color: AppColors.warning),
                  ),
                if (hit.source.contains('filename'))
                  const Positioned(
                    top: 4,
                    right: 4,
                    child: AiStatusPill(text: '文件名', color: AppColors.outline),
                  ),
                if (hit.isVideo)
                  const Positioned(
                    bottom: 4,
                    left: 4,
                    child: AiStatusPill(text: '视频', color: AppColors.primary),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hit.filePath.split('/').last,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Row(
                  children: [
                    if (hit.score > 0)
                      Text(
                        '相关度 ${hit.score.toStringAsFixed(3)}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    const Spacer(),
                    IconButton(
                      onPressed: onSimilar,
                      icon: const Icon(Icons.image_search_rounded, size: 14),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 24, minHeight: 24),
                      tooltip: '以图搜图',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
