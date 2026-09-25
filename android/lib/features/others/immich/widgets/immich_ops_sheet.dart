import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:torrid/features/others/ai/models/ai_search_models.dart';
import 'package:torrid/features/others/ai/services/ai_api_service.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/models/tag.dart';
import 'package:torrid/features/others/gallery/providers/gallery_providers.dart';
import 'package:torrid/features/others/immich/providers/immich_providers.dart';
import 'package:torrid/features/others/immich/widgets/immich_dialogs.dart';
import 'package:torrid/features/others/immich/widgets/immich_tag_tree.dart';

// 底部批量操作栏

/// 多选状态下的底部操作栏
class ImmichSelectionBar extends StatelessWidget {
  final int count;
  final VoidCallback onAddTags;
  final VoidCallback onRemoveTags;
  final VoidCallback onDelete;
  final VoidCallback onRestore;
  final VoidCallback onMessage;
  final VoidCallback onBundle;
  final VoidCallback onUnbundle;
  final VoidCallback onClear;

  const ImmichSelectionBar({
    super.key,
    required this.count,
    required this.onAddTags,
    required this.onRemoveTags,
    required this.onDelete,
    required this.onRestore,
    required this.onMessage,
    required this.onBundle,
    required this.onUnbundle,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      color: scheme.surface,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '已选 $count',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.primary,
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _BarAction(
                        icon: Icons.label_outline,
                        label: '加标签',
                        onTap: onAddTags),
                    _BarAction(
                        icon: Icons.label_off_outlined,
                        label: '移除标签',
                        onTap: onRemoveTags),
                    _BarAction(
                        icon: Icons.link,
                        label: '捆绑',
                        enabled: count >= 2,
                        onTap: onBundle),
                    _BarAction(
                        icon: Icons.link_off,
                        label: '解绑',
                        onTap: onUnbundle),
                    _BarAction(
                        icon: Icons.edit_note,
                        label: '备注',
                        onTap: onMessage),
                    _BarAction(
                        icon: Icons.delete_outline,
                        label: '删除',
                        color: Colors.red,
                        onTap: onDelete),
                    _BarAction(
                        icon: Icons.restore,
                        label: '恢复',
                        color: Colors.green,
                        onTap: onRestore),
                    _BarAction(
                        icon: Icons.close,
                        label: '取消选择',
                        onTap: onClear),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final bool enabled;
  final VoidCallback onTap;

  const _BarAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final tint = enabled ? color : Colors.grey;
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: tint),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: tint),
            ),
          ],
        ),
      ),
    );
  }
}

// 标签选择弹窗

/// 标签选择弹窗 (树状, 支持搜索); 返回勾选的标签 id 集合, null 表示取消
///
/// [restrictTo] 非空时改为平铺列出指定标签 (用于"移除标签")
Future<Set<String>?> showImmichTagPicker(
  BuildContext context, {
  String title = '选择标签',
  Set<String> initialChecked = const {},
  Set<String>? restrictTo,
}) {
  return showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _TagPickerSheet(
      title: title,
      initialChecked: initialChecked,
      restrictTo: restrictTo,
    ),
  );
}

class _TagPickerSheet extends ConsumerStatefulWidget {
  final String title;
  final Set<String> initialChecked;
  final Set<String>? restrictTo;

  const _TagPickerSheet({
    required this.title,
    required this.initialChecked,
    this.restrictTo,
  });

  @override
  ConsumerState<_TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends ConsumerState<_TagPickerSheet> {
  late final Set<String> _checked = {...widget.initialChecked};
  final Set<String> _expanded = {};
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _expandInitialized = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(tagTreeProvider);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: _checked.isEmpty
                      ? null
                      : () => setState(() => _checked.clear()),
                  child: const Text('清空'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, _checked),
                  child: Text(
                    _checked.isEmpty ? '确定' : '确定 (${_checked.length})',
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索标签名或路径',
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
                border: const OutlineInputBorder(),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: tagsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text('标签加载失败: $error',
                    style: const TextStyle(fontSize: 12)),
              ),
              data: (tags) {
                if (tags.isEmpty) {
                  return const Center(
                    child: Text('暂无标签',
                        style: TextStyle(color: Colors.grey, fontSize: 13)),
                  );
                }
                return widget.restrictTo != null
                    ? _buildFlatList(tags)
                    : _buildTreeList(tags);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 平铺模式 (仅列出指定标签)
  Widget _buildFlatList(List<Tag> tags) {
    final restrict = widget.restrictTo!;
    final matched = [
      for (final tag in tags)
        if (restrict.contains(tag.id))
          if (_query.isEmpty ||
              tag.name.toLowerCase().contains(_query) ||
              (tag.fullPath ?? '').toLowerCase().contains(_query))
            tag,
    ]..sort(
        (a, b) => (a.fullPath ?? a.name).compareTo(b.fullPath ?? b.name),
      );
    if (matched.isEmpty) return _buildNoMatch();
    return ListView.builder(
      itemCount: matched.length,
      itemBuilder: (context, index) => _buildTile(
        tag: matched[index],
        depth: 0,
        hasChildren: false,
        expanded: false,
        showPath: true,
      ),
    );
  }

  /// 树状模式
  Widget _buildTreeList(List<Tag> tags) {
    _initExpanded(tags);
    final childrenMap = groupTagsByParent(tags);
    final searching = _query.isNotEmpty;
    final visible = searching ? matchedTagIds(tags, _query) : null;
    if (searching && visible!.isEmpty) return _buildNoMatch();
    final nodes = flattenTagTree(
      childrenMap,
      visible: visible,
      expanded: _expanded,
    );
    return ListView.builder(
      itemCount: nodes.length,
      itemBuilder: (context, index) {
        final node = nodes[index];
        return _buildTile(
          tag: node.tag,
          depth: node.depth,
          hasChildren: node.hasChildren,
          expanded: _expanded.contains(node.tag.id),
          showPath: false,
        );
      },
    );
  }

  Widget _buildNoMatch() => const Center(
        child: Text('未找到匹配的标签',
            style: TextStyle(color: Colors.grey, fontSize: 13)),
      );

  Widget _buildTile({
    required Tag tag,
    required int depth,
    required bool hasChildren,
    required bool expanded,
    required bool showPath,
  }) {
    return CheckboxListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.only(left: 8 + depth * 16.0, right: 4),
      value: _checked.contains(tag.id),
      onChanged: (_) => setState(() {
        if (!_checked.remove(tag.id)) _checked.add(tag.id);
      }),
      title: Text(tag.name, style: const TextStyle(fontSize: 14)),
      subtitle: showPath && tag.fullPath != null && tag.fullPath != tag.name
          ? Text(tag.fullPath!,
              style: const TextStyle(fontSize: 11),
              overflow: TextOverflow.ellipsis)
          : null,
      secondary: hasChildren
          ? IconButton(
              icon: Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                size: 18,
              ),
              onPressed: () => setState(() {
                if (!_expanded.remove(tag.id)) _expanded.add(tag.id);
              }),
            )
          : null,
    );
  }

  void _initExpanded(List<Tag> tags) {
    if (_expandInitialized) return;
    _expandInitialized = true;
    final childrenMap = groupTagsByParent(tags);
    for (final entry in childrenMap.entries) {
      if (entry.key.isEmpty) continue;
      _expanded.add(entry.key);
    }
  }
}

// 捆绑主文件选择

/// 选择捆绑主文件; 返回选中的媒体 id, null 表示取消
Future<String?> showImmichLeadPicker(
  BuildContext context,
  List<MediaAsset> assets,
) {
  return showDialog<String>(
    context: context,
    builder: (_) => _LeadPickerDialog(assets: assets),
  );
}

class _LeadPickerDialog extends StatefulWidget {
  final List<MediaAsset> assets;

  const _LeadPickerDialog({required this.assets});

  @override
  State<_LeadPickerDialog> createState() => _LeadPickerDialogState();
}

class _LeadPickerDialogState extends State<_LeadPickerDialog> {
  late String _leadId = widget.assets.first.id;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('选择主文件'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '其余文件将捆绑到主文件, 不再单独显示。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.assets.length,
                itemBuilder: (context, index) {
                  final asset = widget.assets[index];
                  final selected = asset.id == _leadId;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 20,
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                    ),
                    title: Text(
                      _fileName(asset.filePath),
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => setState(() => _leadId = asset.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _leadId),
          child: const Text('捆绑'),
        ),
      ],
    );
  }
}

// 单张媒体详情

/// 单张媒体详情底部弹窗
Future<void> showImmichMediaDetail(
  BuildContext context, {
  required String mediaId,
  required MediaAsset fallback,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _MediaDetailSheet(mediaId: mediaId, fallback: fallback),
  );
}

class _MediaDetailSheet extends ConsumerStatefulWidget {
  final String mediaId;
  final MediaAsset fallback;

  const _MediaDetailSheet({required this.mediaId, required this.fallback});

  @override
  ConsumerState<_MediaDetailSheet> createState() => _MediaDetailSheetState();
}

class _MediaDetailSheetState extends ConsumerState<_MediaDetailSheet> {
  bool _busy = false;

  /// 列表未覆盖该媒体时兜底拉取一次标签（多页刷新后仍能正确显示）
  List<String>? _fetchedTagIds;

  /// 该媒体的 AI 分析结果（只读展示，不参与编辑）
  AiMediaDetail? _aiDetail;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureTagsLoaded();
      _loadAiDetail();
    });
  }

  Future<void> _ensureTagsLoaded() async {
    final page = ref.read(immichMediaProvider).valueOrNull;
    if (page != null && page.tagIdsByMedia.containsKey(widget.mediaId)) return;
    try {
      final result = await ref.read(galleryApiProvider).queryMedia(
            ids: [widget.mediaId],
            includeDeleted: true,
            limit: 1,
          );
      final ids = [
        for (final link in result.mediaTagLinks)
          if (link.mediaId == widget.mediaId) link.tagId,
      ];
      if (mounted) setState(() => _fetchedTagIds = ids);
    } catch (_) {
      // 拉取失败时保持空标签展示, 不做额外提示
    }
  }

  /// AI 结果读取失败（未初始化 AI 层 / 离线）时整块不展示。
  Future<void> _loadAiDetail() async {
    try {
      final detail = await ref.read(aiApiProvider).fetchMediaDetail(widget.mediaId);
      if (mounted) setState(() => _aiDetail = detail);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(immichMediaProvider).valueOrNull;
    final asset = _findAsset(page, widget.mediaId) ?? widget.fallback;
    final tagIds = page?.tagIdsByMedia[widget.mediaId] ??
        _fetchedTagIds ??
        const <String>[];
    final tags = ref.watch(tagTreeProvider).valueOrNull ?? const <Tag>[];
    final byId = {for (final tag in tags) tag.id: tag};
    final linkedTags = [
      for (final id in tagIds)
        if (byId[id] != null) byId[id]!,
    ]..sort(
        (a, b) => (a.fullPath ?? a.name).compareTo(b.fullPath ?? b.name),
      );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_busy) const LinearProgressIndicator(minHeight: 2),
            Row(
              children: [
                Icon(
                  asset.isVideo ? Icons.videocam : Icons.image,
                  size: 18,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _fileName(asset.filePath),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (asset.isDeleted)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('已删除',
                        style: TextStyle(fontSize: 10, color: Colors.white)),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            _InfoRow(
              icon: Icons.schedule,
              text: DateFormat('yyyy-MM-dd HH:mm').format(asset.capturedAt),
            ),
            _InfoRow(icon: Icons.sd_storage_outlined, text: _formatSize(asset.sizeBytes)),
            if (asset.isGroupMember)
              const _InfoRow(icon: Icons.link, text: '已捆绑到其他文件'),
            const Divider(height: 24),
            Row(
              children: [
                const Text('备注',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _editMessage(asset),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('编辑', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            Text(
              (asset.message == null || asset.message!.isEmpty)
                  ? '暂无备注'
                  : asset.message!,
              style: TextStyle(
                fontSize: 13,
                color: (asset.message == null || asset.message!.isEmpty)
                    ? Colors.grey
                    : null,
              ),
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Text('标签',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _editTags(asset, tagIds),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('修改', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            if (linkedTags.isEmpty)
              const Text('暂无标签',
                  style: TextStyle(fontSize: 12, color: Colors.grey))
            else
              Wrap(
                spacing: 6,
                runSpacing: 0,
                children: [
                  for (final tag in linkedTags)
                    InputChip(
                      label: Text(tag.name,
                          style: const TextStyle(fontSize: 12)),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onDeleted: () => _removeTag(asset, tag.id),
                    ),
                ],
              ),
            if (_aiDetail != null && !_aiDetail!.isEmpty) ...[
              const Divider(height: 24),
              Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 16, color: Colors.teal),
                  const SizedBox(width: 6),
                  const Text('AI 标签',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  Text('只读',
                      style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                ],
              ),
              const SizedBox(height: 6),
              if (_aiDetail!.vlmTags.isEmpty)
                const Text('暂无 AI 标签',
                    style: TextStyle(fontSize: 12, color: Colors.grey))
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final tag in _aiDetail!.vlmTags)
                      Chip(
                        label: Text(tag, style: const TextStyle(fontSize: 12)),
                        avatar: const Icon(Icons.auto_awesome,
                            size: 14, color: Colors.teal),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: BorderSide(
                          color: Colors.teal.withValues(alpha: 0.35),
                        ),
                      ),
                  ],
                ),
              if (_aiDetail!.caption != null) ...[
                const SizedBox(height: 10),
                Text('AI 描述',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 2),
                Text(_aiDetail!.caption!, style: const TextStyle(fontSize: 13)),
              ],
            ],
            const Divider(height: 24),
            Row(
              children: [
                if (asset.isDeleted)
                  OutlinedButton.icon(
                    onPressed: () => _setDeleted(asset, false),
                    icon: const Icon(Icons.restore, size: 18),
                    label: const Text('恢复'),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () => _setDeleted(asset, true),
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: Colors.red),
                    label: const Text('删除',
                        style: TextStyle(color: Colors.red)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 操作

  Future<void> _run(Future<void> Function() action, {String? ok}) async {
    setState(() => _busy = true);
    try {
      await action();
      if (ok != null) _snack(ok);
    } catch (e) {
      _snack('操作失败: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editMessage(MediaAsset asset) async {
    final text = await showImmichTextDialog(
      context,
      title: '编辑备注',
      initial: asset.message ?? '',
      label: '备注',
      hint: '留空即清除备注',
      maxLines: 3,
    );
    if (text == null) return;
    await _run(
      () => ref
          .read(immichActionsProvider.notifier)
          .setMessage([asset.id], text),
      ok: '备注已更新',
    );
  }

  Future<void> _editTags(MediaAsset asset, List<String> currentIds) async {
    final picked = await showImmichTagPicker(
      context,
      title: '编辑标签',
      initialChecked: currentIds.toSet(),
    );
    if (picked == null) return;
    final current = currentIds.toSet();
    final toAdd = picked.difference(current).toList();
    final toRemove = current.difference(picked).toList();
    if (toAdd.isEmpty && toRemove.isEmpty) return;
    await _run(() async {
      final actions = ref.read(immichActionsProvider.notifier);
      if (toAdd.isNotEmpty) await actions.addTags([asset.id], toAdd);
      if (toRemove.isNotEmpty) await actions.removeTags([asset.id], toRemove);
    }, ok: '标签已更新');
  }

  Future<void> _removeTag(MediaAsset asset, String tagId) async {
    await _run(
      () => ref
          .read(immichActionsProvider.notifier)
          .removeTags([asset.id], [tagId]),
      ok: '已移除标签',
    );
  }

  Future<void> _setDeleted(MediaAsset asset, bool deleted) async {
    if (deleted) {
      final confirmed = await showImmichConfirmDialog(
        context,
        title: '删除媒体',
        message: '确定删除 "${_fileName(asset.filePath)}" 吗?',
        confirmText: '删除',
        danger: true,
      );
      if (!confirmed) return;
    }
    await _run(
      () => ref
          .read(immichActionsProvider.notifier)
          .setDeleted([asset.id], deleted),
      ok: deleted ? '已删除' : '已恢复',
    );
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }
}

// 工具

MediaAsset? _findAsset(ImmichMediaPage? page, String mediaId) {
  for (final asset in page?.assets ?? const <MediaAsset>[]) {
    if (asset.id == mediaId) return asset;
  }
  return null;
}

String _fileName(String path) => path.split(RegExp(r'[\\/]')).last;

String _formatSize(int bytes) {
  if (bytes <= 0) return '大小未知';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}
