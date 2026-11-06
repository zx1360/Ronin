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
import 'package:torrid/features/others/immich/widgets/immich_media_grid.dart';
import 'package:torrid/features/others/immich/widgets/immich_tag_picker.dart';

class ImmichSelectionBar extends StatelessWidget {
  final int count;
  final bool busy;
  final VoidCallback onClear;
  final ValueChanged<bool> onEditTags;
  final VoidCallback? onDelete;
  final VoidCallback? onRestore;
  final VoidCallback? onMessage;
  final VoidCallback? onBundle;
  final VoidCallback? onUnbundle;
  final VoidCallback? onShare;

  const ImmichSelectionBar({
    super.key,
    required this.count,
    required this.busy,
    required this.onClear,
    required this.onEditTags,
    this.onDelete,
    this.onRestore,
    this.onMessage,
    this.onBundle,
    this.onUnbundle,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final actions = [
      (Icons.label_outline, '加标签', () => onEditTags(false)),
      (Icons.label_off_outlined, '移除标签', () => onEditTags(true)),
      (Icons.link, '捆绑', onBundle),
      (Icons.delete_outline, '标记待删除', onDelete),
      (Icons.restore, '恢复', onRestore),
      (Icons.link_off, '解绑', onUnbundle),
      (Icons.share, '分享', onShare),
      (Icons.edit_note, '备注', onMessage),
    ];
    return Material(
      elevation: 4,
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
                  style: TextStyle(color: scheme.primary),
                ),
              ),
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final (icon, label, action) in actions)
                      if (action != null)
                        InkWell(
                          onTap: busy ? null : action,
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 48),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  icon,
                                  size: 20,
                                  color: busy ? scheme.outline : null,
                                ),
                                const SizedBox(height: 2),
                                Text(label, style: theme.textTheme.labelMedium),
                              ],
                            ),
                          ),
                        ),
                  ],
                ),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close),
                  tooltip: '退出多选',
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// 捆绑主文件选择

Future<({String leadId, List<String> memberIds})?> showImmichBundleDialog(
  BuildContext context,
  List<MediaAsset> assets,
) async {
  final leadId = await showDialog<String>(
    context: context,
    builder: (_) => _LeadPickerDialog(assets: assets),
  );
  if (leadId == null) return null;
  return (
    leadId: leadId,
    memberIds: [
      for (final asset in assets)
        if (asset.id != leadId) asset.id,
    ],
  );
}

class _LeadPickerDialog extends StatefulWidget {
  final List<MediaAsset> assets;

  const _LeadPickerDialog({required this.assets});

  @override
  State<_LeadPickerDialog> createState() => _LeadPickerDialogState();
}

class _LeadPickerDialogState extends State<_LeadPickerDialog> {
  bool _canLead(MediaAsset asset) => !asset.isDeleted && asset.isGroupLead;

  late String? _leadId = widget.assets.where(_canLead).firstOrNull?.id;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('选择主文件'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _leadId == null
                  ? '所选媒体中没有可作为主文件的项。'
                  : '其余所选文件会加入主文件。若其中已有捆绑组，组内成员会一并移入。',
              style: theme.textTheme.bodySmall,
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
                  final canLead = _canLead(asset);
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    enabled: canLead,
                    selected: selected,
                    leading: SizedBox.square(
                      dimension: 40,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: ImmichThumb(asset: asset),
                      ),
                    ),
                    trailing: Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 20,
                    ),
                    title: Text(
                      _fileName(asset.filePath),
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: canLead
                        ? null
                        : Text(asset.isDeleted ? '待删除' : '已是其他主文件的成员'),
                    onTap: canLead
                        ? () => setState(() => _leadId = asset.id)
                        : null,
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
          onPressed: _leadId == null
              ? null
              : () => Navigator.pop(context, _leadId),
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
  late MediaAsset _asset = widget.fallback;
  List<String>? _tagIds;
  bool _loadFailed = false;
  AiMediaDetail? _aiDetail;

  @override
  void initState() {
    super.initState();
    _loadMedia();
    _loadAiDetail();
  }

  Future<void> _loadMedia() async {
    try {
      final result = await ref
          .read(galleryApiProvider)
          .queryMedia(ids: [widget.mediaId], includeDeleted: true, limit: 1);
      final asset = result.mediaAssets.firstOrNull;
      if (asset == null) throw StateError('媒体已不存在');
      if (!mounted) return;
      setState(() {
        _asset = asset;
        _tagIds = result.mediaTagLinks.map((link) => link.tagId).toList();
        _loadFailed = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _tagIds = null;
          _loadFailed = true;
        });
      }
    }
  }

  /// AI 结果读取失败（未初始化 AI 层 / 离线）时整块不展示。
  Future<void> _loadAiDetail() async {
    try {
      final detail = await ref
          .read(aiApiProvider)
          .fetchMediaDetail(widget.mediaId);
      if (mounted) setState(() => _aiDetail = detail);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final asset = _asset;
    final tagIds = _tagIds;
    final busy = _busy || ref.watch(immichActionsProvider);
    final canEdit = !busy && tagIds != null;
    final tags = ref.watch(tagTreeProvider).valueOrNull ?? const <Tag>[];
    final byId = {for (final tag in tags) tag.id: tag};
    final linkedTags = [
      for (final id in tagIds ?? const <String>[])
        if (byId[id] != null) byId[id]!,
    ]..sort((a, b) => (a.fullPath ?? a.name).compareTo(b.fullPath ?? b.name));

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
            if (busy) const LinearProgressIndicator(minHeight: 2),
            if (_loadFailed)
              TextButton.icon(
                onPressed: busy ? null : _loadMedia,
                icon: const Icon(Icons.refresh),
                label: const Text('详情加载失败，重试'),
              ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '待删除',
                      style: TextStyle(fontSize: 10, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            _InfoRow(
              icon: Icons.schedule,
              text: DateFormat(
                'yyyy-MM-dd HH:mm',
              ).format(asset.capturedAt.toLocal()),
            ),
            _InfoRow(
              icon: Icons.sd_storage_outlined,
              text: _formatSize(asset.sizeBytes),
            ),
            if (asset.isGroupMember)
              const _InfoRow(icon: Icons.link, text: '已捆绑到其他文件'),
            const Divider(height: 24),
            Row(
              children: [
                const Text(
                  '备注',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: canEdit ? () => _editMessage(asset) : null,
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
                const Text(
                  '人工标签',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: canEdit ? () => _editTags(asset, tagIds) : null,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('修改', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            if (linkedTags.isEmpty)
              Text(
                tagIds != null
                    ? '暂无标签'
                    : _loadFailed
                    ? '标签暂不可用'
                    : '正在加载标签…',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 0,
                children: [
                  for (final tag in linkedTags)
                    InputChip(
                      label: Text(
                        tag.name,
                        style: const TextStyle(fontSize: 12),
                      ),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onDeleted: canEdit
                          ? () => _removeTag(asset, tag.id)
                          : null,
                    ),
                ],
              ),
            if (_aiDetail != null && !_aiDetail!.isEmpty) ...[
              const Divider(height: 24),
              Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 16, color: Colors.teal),
                  const SizedBox(width: 6),
                  const Text(
                    'AI 标签',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '只读',
                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (_aiDetail!.vlmTags.isEmpty)
                const Text(
                  '暂无 AI 标签',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final tag in _aiDetail!.vlmTags)
                      Chip(
                        label: Text(tag, style: const TextStyle(fontSize: 12)),
                        avatar: const Icon(
                          Icons.auto_awesome,
                          size: 14,
                          color: Colors.teal,
                        ),
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
                Text(
                  'AI 描述',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 2),
                Text(_aiDetail!.caption!, style: const TextStyle(fontSize: 13)),
              ],
              if (_aiDetail!.ocrText case final ocr?) ...[
                const SizedBox(height: 10),
                const Text('识别文字'),
                SelectableText(ocr, style: const TextStyle(fontSize: 13)),
              ],
            ],
            const Divider(height: 24),
            Row(
              children: [
                if (asset.isDeleted)
                  OutlinedButton.icon(
                    onPressed: canEdit ? () => _setDeleted(asset, false) : null,
                    icon: const Icon(Icons.restore, size: 18),
                    label: const Text('恢复'),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: canEdit ? () => _setDeleted(asset, true) : null,
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: Colors.red,
                    ),
                    label: const Text(
                      '标记待删除',
                      style: TextStyle(color: Colors.red),
                    ),
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
      if (mounted) await _loadMedia();
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
    if (!mounted || text == null) return;
    await _run(
      () =>
          ref.read(immichActionsProvider.notifier).setMessage([asset.id], text),
      ok: '备注已更新',
    );
  }

  Future<void> _editTags(MediaAsset asset, List<String> currentIds) async {
    final picked = await showImmichTagPicker(
      context,
      title: '编辑标签',
      initialChecked: currentIds.toSet(),
    );
    if (!mounted || picked == null) return;
    final current = currentIds.toSet();
    final toAdd = picked.difference(current).toList();
    final toRemove = current.difference(picked).toList();
    if (toAdd.isEmpty && toRemove.isEmpty) return;
    await _run(
      () => ref
          .read(immichActionsProvider.notifier)
          .editTags([asset.id], add: toAdd, remove: toRemove),
      ok: '标签已更新',
    );
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
    if (deleted && !await confirmAlbumDeletion(context, 1)) return;
    if (!mounted) return;
    await _run(
      () => ref.read(immichActionsProvider.notifier).setDeleted([
        asset.id,
      ], deleted),
      ok: deleted ? '已标记待删除' : '已恢复',
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

String _fileName(String path) => path.split(RegExp(r'[\\/]')).last;

String _formatSize(int bytes) {
  if (bytes <= 0) return '大小未知';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}
