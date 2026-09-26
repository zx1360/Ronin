import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:northstar/app/theme.dart';
import 'package:northstar/core/providers/ai/ai_providers.dart';
import 'package:northstar/core/providers/gallery/gallery_providers.dart';
import 'package:northstar/core/providers/ops/ops_settings_provider.dart';
import 'package:northstar/ui/ai/widgets/media_tile.dart';

/// 已软删除的媒体：查看清单并取消软删除标记。
///
/// 本页只改数据库标记，不碰任何文件——真正的删除仍由 Gallery CLI 执行。
class AiDeletedTab extends ConsumerStatefulWidget {
  const AiDeletedTab({super.key});

  @override
  ConsumerState<AiDeletedTab> createState() => _AiDeletedTabState();
}

class _AiDeletedTabState extends ConsumerState<AiDeletedTab> {
  bool _busy = false;
  bool _loadedOnce = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(deletedMediaControllerProvider);
    final controller = ref.read(deletedMediaControllerProvider.notifier);
    final settings = ref.watch(opsSettingsControllerProvider);
    final client = ref.read(aiApiClientProvider);
    final thumbBase = client.galleryBaseUrl(settings);
    final selection = state.selection;

    return Padding(
      padding: const EdgeInsets.all(AppDimens.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _busy
                    ? null
                    : () {
                        setState(() => _loadedOnce = true);
                        controller.load();
                      },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text(_loadedOnce ? '刷新' : '加载已删除媒体'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: AppDimens.spacingS),
              if (_loadedOnce)
                Text('共 ${state.total} 个 · 已选 ${selection.length}',
                    style: Theme.of(context).textTheme.bodySmall),
              const Spacer(),
              if (state.loading || _busy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '这些文件只有数据库里的软删除标记，磁盘文件仍在。'
            '取消标记即恢复；确认删除请走「任务管理」里的 Gallery execute。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                state.error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ),
          const SizedBox(height: AppDimens.spacingS),
          Expanded(child: _buildBody(state, thumbBase)),
          if (selection.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppDimens.spacingS),
              child: Row(
                children: [
                  TextButton(
                    onPressed: controller.clearSelection,
                    child: const Text('取消选择'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _restore(selection.toList()),
                    icon: const Icon(Icons.restore, size: 16),
                    label: Text('取消软删除 (${selection.length})'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(DeletedMediaState state, String thumbBase) {
    if (!_loadedOnce) {
      return const Center(child: Text('点击上方按钮加载已软删除的媒体'));
    }
    if (state.loading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.items.isEmpty) {
      return const Center(child: Text('没有被软删除的媒体'));
    }

    final controller = ref.read(deletedMediaControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in state.items)
                  AiMediaTile(
                    thumbUrl: '$thumbBase/${item.id}/thumb',
                    fileName: item.fileName,
                    selected: state.selection.contains(item.id),
                    onTap: () => controller.toggle(item.id),
                    onReveal: () => revealMediaFile(context, ref, item.filePath),
                  ),
              ],
            ),
          ),
        ),
        if (state.hasMore)
          Padding(
            padding: const EdgeInsets.only(top: AppDimens.spacingS),
            child: Center(
              child: TextButton(
                onPressed: state.loading ? null : () => controller.load(more: true),
                child: Text('加载更多（已显示 ${state.items.length} / ${state.total}）'),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _restore(List<String> ids) async {
    setState(() => _busy = true);
    try {
      final count =
          await ref.read(deletedMediaControllerProvider.notifier).restoreSelected();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已取消 $count 个文件的软删除标记')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('恢复失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
