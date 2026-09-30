import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:northstar/app/theme.dart';
import 'package:northstar/core/providers/ai/ai_providers.dart';
import 'package:northstar/core/providers/gallery/gallery_providers.dart';
import 'package:northstar/core/providers/ops/ops_settings_provider.dart';
import 'package:northstar/domain/ai/models/ai_models.dart';
import 'package:northstar/domain/gallery/models/gallery_media.dart';
import 'package:northstar/ui/ai/widgets/media_tile.dart';

/// 近重复分组（pHash）：查看每组、标记删除、把剩余图片标记为「非重复」。
///
/// 删除只是软删除（与画廊一致），真正落盘由 Gallery CLI 执行。
class AiDuplicatesTab extends ConsumerStatefulWidget {
  const AiDuplicatesTab({super.key});

  @override
  ConsumerState<AiDuplicatesTab> createState() => _AiDuplicatesTabState();
}

class _AiDuplicatesTabState extends ConsumerState<AiDuplicatesTab> {
  bool _requested = false;
  bool _busy = false;

  /// 已选中的媒体 ID（跨组共享；按组操作时只用组内交集）。
  final Set<String> _selected = {};

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
                onPressed: _busy
                    ? null
                    : () {
                        setState(() {
                          _requested = true;
                          _selected.clear();
                        });
                        ref.invalidate(duplicateGroupsProvider);
                      },
                icon: const Icon(Icons.filter_none_rounded, size: 16),
                label: Text(_requested ? '重新计算' : '计算近重复分组'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: AppDimens.spacingS),
              const Spacer(),
              if (_busy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '基于 pHash 感知哈希：汉明距离 ≤ 4 的图片会被归为一组，'
            '可识别同一张图的缩放、转码、加水印等变体。'
            '「标记删除」是软删除（可在「已删除」页取消）；'
            '「标记非重复」用于同组里其实不是重复的图，标记后不再参与分组。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppDimens.spacingS),
          Expanded(
            child: !_requested
                ? const Center(child: Text('点击上方按钮开始计算'))
                : ref.watch(duplicateGroupsProvider).when(
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
                      data: (result) => _buildGroups(
                        context,
                        result,
                        client.galleryBaseUrl(settings),
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroups(
    BuildContext context,
    DuplicatesResult result,
    String thumbBase,
  ) {
    if (result.groups.isEmpty && result.ignoredTotal == 0) {
      return const Center(child: Text('未发现近重复图片'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('共 ${result.groups.length} 组',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(width: AppDimens.spacingS),
            if (result.ignoredTotal > 0)
              TextButton.icon(
                onPressed: _showIgnored,
                icon: const Icon(Icons.visibility_off_outlined, size: 14),
                label: Text('已忽略 ${result.ignoredTotal} 张'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppDimens.spacingXS),
        Expanded(
          child: ListView.separated(
            itemCount: result.groups.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _GroupCard(
              group: result.groups[index],
              thumbBase: thumbBase,
              selected: _selected,
              onToggle: (id) => setState(() {
                if (!_selected.remove(id)) _selected.add(id);
              }),
              onReveal: (filePath) => revealMediaFile(context, ref, filePath),
              onDelete: (ids) => _markDeleted(ids),
              onIgnore: (ids) => _markIgnored(ids),
            ),
          ),
        ),
      ],
    );
  }

  /// 标记软删除（可回退，故不弹确认框；结果如实提示）。
  Future<void> _markDeleted(List<String> ids) async {
    if (ids.isEmpty) return;
    await _run(() async {
      final settings = ref.read(opsSettingsControllerProvider);
      final count = await ref
          .read(galleryApiClientProvider)
          .setDeleted(settings, ids, deleted: true);
      return '已标记软删除 $count 张（可在「已删除」页取消）';
    }, removeIds: ids);
  }

  /// 标记为「非重复」：之后不再出现在近重复分组里。
  Future<void> _markIgnored(List<String> ids) async {
    if (ids.isEmpty) return;
    await _run(() async {
      final settings = ref.read(opsSettingsControllerProvider);
      await ref.read(aiApiClientProvider).ignoreDuplicates(settings, ids);
      return '已把 ${ids.length} 张标记为非重复';
    }, removeIds: ids);
  }

  Future<void> _run(
    Future<String> Function() action, {
    required List<String> removeIds,
  }) async {
    setState(() => _busy = true);
    try {
      final message = await action();
      if (!mounted) return;
      setState(() => _selected.removeAll(removeIds));
      ref.invalidate(duplicateGroupsProvider);
      ref.invalidate(ignoredDuplicatesProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('操作失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 已标记「非重复」的媒体：可逐张或全部恢复。
  Future<void> _showIgnored() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Consumer(
        builder: (context, ref, _) => AlertDialog(
          title: const Text('已标记为非重复'),
          content: SizedBox(
            width: 520,
            height: 360,
            child: ref.watch(ignoredDuplicatesProvider).when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(child: Text(error.toString())),
                  data: (items) => items.isEmpty
                      ? const Center(child: Text('暂无记录'))
                      : _IgnoredList(
                          items: items,
                          onRestore: (ids) => _restoreIgnored(dialogContext, ids),
                        ),
                ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('关闭'),
            ),
            TextButton(
              onPressed: () async {
                final items =
                    ref.read(ignoredDuplicatesProvider).valueOrNull ?? const [];
                await _restoreIgnored(
                  dialogContext,
                  items.map((item) => item.id).toList(),
                );
              },
              child: const Text('全部恢复'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _restoreIgnored(BuildContext dialogContext, List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      final settings = ref.read(opsSettingsControllerProvider);
      await ref.read(aiApiClientProvider).unignoreDuplicates(settings, ids);
      ref.invalidate(ignoredDuplicatesProvider);
      ref.invalidate(duplicateGroupsProvider);
      if (dialogContext.mounted) Navigator.pop(dialogContext);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('恢复失败: $e')));
      }
    }
  }
}

/// 恢复列表（每组缩略图 + 文件名 + 恢复按钮）。
class _IgnoredList extends StatelessWidget {
  const _IgnoredList({required this.items, required this.onRestore});

  final List<GalleryMedia> items;
  final void Function(List<String> ids) onRestore;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          title: Text(item.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12)),
          subtitle: Text(item.filePath,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall),
          trailing: TextButton(
            onPressed: () => onRestore([item.id]),
            child: const Text('恢复'),
          ),
        );
      },
    );
  }
}

/// 一组近重复图片。
class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.thumbBase,
    required this.selected,
    required this.onToggle,
    required this.onReveal,
    required this.onDelete,
    required this.onIgnore,
  });

  final AiDuplicateGroup group;

  /// 形如 `https://host:port/API/gallery`，用于拼缩略图地址。
  final String thumbBase;
  final Set<String> selected;
  final void Function(String id) onToggle;
  final void Function(String filePath) onReveal;
  final void Function(List<String> ids) onDelete;
  final void Function(List<String> ids) onIgnore;

  @override
  Widget build(BuildContext context) {
    final selectedInGroup = [
      for (final id in group.mediaIds)
        if (selected.contains(id)) id,
    ];

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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < group.mediaIds.length; i++)
                  AiMediaTile(
                    thumbUrl: '$thumbBase/${group.mediaIds[i]}/thumb',
                    fileName: i < group.files.length && group.files[i].isNotEmpty
                        ? group.files[i].split(RegExp(r'[/\\]')).last
                        : group.mediaIds[i],
                    selected: selected.contains(group.mediaIds[i]),
                    onTap: () => onToggle(group.mediaIds[i]),
                    onReveal: i < group.files.length && group.files[i].isNotEmpty
                        ? () => onReveal(group.files[i])
                        : null,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  selectedInGroup.isEmpty
                      ? '点击图片选择要处理的文件'
                      : '组内已选 ${selectedInGroup.length} 张',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: selectedInGroup.isEmpty
                      ? null
                      : () => onDelete(selectedInGroup),
                  icon: const Icon(Icons.delete_outline, size: 14),
                  label: const Text('标记删除'),
                ),
                TextButton.icon(
                  onPressed: selectedInGroup.isEmpty
                      ? null
                      : () => onIgnore(selectedInGroup),
                  icon: const Icon(Icons.thumb_down_alt_outlined, size: 14),
                  label: const Text('标记非重复'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
