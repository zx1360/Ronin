import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/models/tag.dart';
import 'package:torrid/features/others/gallery/models/tag_tree.dart';
import 'package:torrid/features/others/gallery/providers/gallery_providers.dart';
import 'package:torrid/features/others/immich/providers/immich_providers.dart';

final _assignedTagsProvider = FutureProvider.autoDispose
    .family<List<Tag>, List<String>>((ref, ids) async {
      final api = ref.watch(galleryApiProvider);
      final cached = ref.read(tagTreeProvider).value ?? const <Tag>[];
      final token = CancelToken();
      ref.onDispose(token.cancel);
      final assigned = await api.fetchAssignedTagIds(ids, cancelToken: token);
      final known = cached.where((tag) => assigned.contains(tag.id)).toList();
      if (known.length == assigned.length) return known;
      final tags = await api.fetchTags();
      return tags.where((tag) => assigned.contains(tag.id)).toList();
    });

Future<void> editAlbumSelectionTags(
  BuildContext context,
  WidgetRef ref,
  List<MediaAsset> selection, {
  required bool remove,
  required VoidCallback onApplied,
}) async {
  final ids = [for (final asset in selection) asset.id];
  if (ids.isEmpty) return;
  final label = remove ? '移除标签' : '添加标签';
  final tags = await showImmichTagPicker(
    context,
    title: '$label · ${ids.length} 项',
    removeFrom: remove ? ids : const [],
    allowEmpty: false,
  );
  if (!context.mounted || tags == null || tags.isEmpty) return;
  final actions = ref.read(immichActionsProvider.notifier);
  var message = '已$label';
  try {
    if (remove) {
      await actions.removeTags(ids, tags.toList());
    } else {
      await actions.addTags(ids, tags.toList());
    }
    if (context.mounted) onApplied();
  } catch (error) {
    message = '$label失败：$error';
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..removeCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 72),
        duration: const Duration(seconds: 2),
      ),
    );
}

Future<Set<String>?> showImmichTagPicker(
  BuildContext context, {
  String title = '选择标签',
  Set<String> initialChecked = const {},
  List<String> removeFrom = const [],
  bool allowEmpty = true,
}) {
  return showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _TagPickerSheet(
      title: title,
      initialChecked: initialChecked,
      removeFrom: removeFrom,
      allowEmpty: allowEmpty,
    ),
  );
}

class _TagPickerSheet extends ConsumerStatefulWidget {
  final String title;
  final Set<String> initialChecked;
  final List<String> removeFrom;
  final bool allowEmpty;

  const _TagPickerSheet({
    required this.title,
    required this.initialChecked,
    required this.removeFrom,
    required this.allowEmpty,
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

  bool get _removing => widget.removeFrom.isNotEmpty;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = _removing
        ? _assignedTagsProvider(widget.removeFrom)
        : tagTreeProvider;
    final tagsAsync = ref.watch(provider);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SizedBox(
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
                      onPressed: !widget.allowEmpty && _checked.isEmpty
                          ? null
                          : () => Navigator.pop(context, Set.of(_checked)),
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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  onChanged: (value) =>
                      setState(() => _query = value.trim().toLowerCase()),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: tagsAsync.when(
                  skipLoadingOnRefresh: false,
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('标签加载失败：$error', textAlign: TextAlign.center),
                        TextButton(
                          onPressed: () => ref.invalidate(provider),
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  ),
                  data: (tags) {
                    if (tags.isEmpty) {
                      return Center(
                        child: Text(_removing ? '所选媒体没有标签' : '暂无标签'),
                      );
                    }
                    return Column(
                      children: [
                        if (_query.isEmpty) _buildFavorites(tags),
                        Expanded(child: _buildTreeList(tags)),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFavorites(List<Tag> tags) {
    final favorites = tags.where((tag) => tag.isFavorite).toList()
      ..sort(compareTagsByPath);
    if (favorites.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Text('常用标签'),
          ),
          for (final tag in favorites)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Tooltip(
                message: tag.fullPath ?? tag.name,
                child: FilterChip(
                  label: Text(tag.name),
                  selected: _checked.contains(tag.id),
                  onSelected: (_) => _toggle(tag.id),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTreeList(List<Tag> tags) {
    final childrenMap = groupTagsByParent(tags);
    if (!_expandInitialized) {
      _expanded.addAll(childrenMap.keys.where((id) => id.isNotEmpty));
      _expandInitialized = true;
    }
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
        );
      },
    );
  }

  Widget _buildNoMatch() => const Center(
    child: Text('未找到匹配的标签', style: TextStyle(color: Colors.grey, fontSize: 13)),
  );

  Widget _buildTile({
    required Tag tag,
    required int depth,
    required bool hasChildren,
    required bool expanded,
  }) {
    return CheckboxListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.only(left: 8 + depth * 16.0, right: 4),
      value: _checked.contains(tag.id),
      onChanged: (_) => _toggle(tag.id),
      title: Text(tag.name, style: const TextStyle(fontSize: 14)),
      subtitle: _removing && tag.fullPath != null && tag.fullPath != tag.name
          ? Text(
              tag.fullPath!,
              style: const TextStyle(fontSize: 11),
              overflow: TextOverflow.ellipsis,
            )
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

  void _toggle(String id) => setState(() {
    if (!_checked.remove(id)) _checked.add(id);
  });
}
