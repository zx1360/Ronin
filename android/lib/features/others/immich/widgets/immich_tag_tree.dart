import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/gallery/models/tag.dart';
import 'package:torrid/features/others/gallery/providers/gallery_providers.dart';
import 'package:torrid/features/others/immich/providers/immich_providers.dart';
import 'package:torrid/features/others/immich/widgets/immich_dialogs.dart';

// ============ 标签树通用工具 ============

/// 扁平化后的树节点
class ImmichTagNode {
  final Tag tag;
  final int depth;
  final bool hasChildren;

  const ImmichTagNode({
    required this.tag,
    required this.depth,
    required this.hasChildren,
  });
}

/// 按父级分组 (父级不存在的标签视为根级), 同级按名称排序
Map<String, List<Tag>> groupTagsByParent(List<Tag> tags) {
  final byId = {for (final tag in tags) tag.id: tag};
  final map = <String, List<Tag>>{};
  for (final tag in tags) {
    final parentId = tag.parentId;
    final key =
        (parentId != null && byId.containsKey(parentId)) ? parentId : '';
    map.putIfAbsent(key, () => []).add(tag);
  }
  for (final list in map.values) {
    list.sort((a, b) => a.name.compareTo(b.name));
  }
  return map;
}

/// 扁平化标签树; [visible] 非空时仅保留其中的标签并强制展开
List<ImmichTagNode> flattenTagTree(
  Map<String, List<Tag>> childrenMap, {
  Set<String>? visible,
  Set<String> expanded = const {},
}) {
  final result = <ImmichTagNode>[];
  void walk(String parentKey, int depth) {
    for (final tag in childrenMap[parentKey] ?? const <Tag>[]) {
      if (visible != null && !visible.contains(tag.id)) continue;
      final hasChildren = (childrenMap[tag.id] ?? const <Tag>[]).isNotEmpty;
      result.add(
        ImmichTagNode(tag: tag, depth: depth, hasChildren: hasChildren),
      );
      if (hasChildren && (visible != null || expanded.contains(tag.id))) {
        walk(tag.id, depth + 1);
      }
    }
  }

  walk('', 0);
  return result;
}

/// 搜索命中的标签 id 及其全部祖先
Set<String> matchedTagIds(List<Tag> tags, String query) {
  if (query.isEmpty) return {};
  final byId = {for (final tag in tags) tag.id: tag};
  final keep = <String>{};
  for (final tag in tags) {
    final hit = tag.name.toLowerCase().contains(query) ||
        (tag.fullPath ?? '').toLowerCase().contains(query);
    if (!hit) continue;
    keep.add(tag.id);
    var parentId = tag.parentId;
    while (parentId != null) {
      if (!keep.add(parentId)) break;
      parentId = byId[parentId]?.parentId;
    }
  }
  return keep;
}

/// 标签树管理面板 (相册页 Drawer)
///
/// - 点击行: 切换该标签的筛选选中 (多选累积)
/// - 行尾 ★: 切换快捷标签; 菜单: 添加子标签 / 重命名 / 移至根级 / 删除
class ImmichTagTreePanel extends ConsumerStatefulWidget {
  const ImmichTagTreePanel({super.key});

  @override
  ConsumerState<ImmichTagTreePanel> createState() => _ImmichTagTreePanelState();
}

class _ImmichTagTreePanelState extends ConsumerState<ImmichTagTreePanel> {
  final Set<String> _expanded = {};
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _expandInitialized = false;
  bool _showFavorites = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(tagTreeProvider);
    final filter = ref.watch(immichFilterNotifierProvider);
    final favorites = ref.watch(favoriteTagsProvider);

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  Text('标签', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('完成'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '搜索标签名或路径',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showAddDialog(null),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('新建根标签',
                          style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () =>
                        ref.read(immichFilterNotifierProvider.notifier).reset(),
                    child: const Text('清除筛选',
                        style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
            if (favorites.isNotEmpty) _buildFavoriteSection(favorites, filter),
            const Divider(height: 1),
            Expanded(
              child: tagsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('标签加载失败: $error',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => ref.invalidate(tagTreeProvider),
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (tags) {
                  if (tags.isEmpty) {
                    return const Center(
                      child: Text('暂无标签',
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                    );
                  }
                  _initExpanded(tags, filter.tagIds);
                  final searching = _query.isNotEmpty;
                  final visible = searching ? matchedTagIds(tags, _query) : null;
                  if (searching && (visible == null || visible.isEmpty)) {
                    return const Center(
                      child: Text('未找到匹配的标签',
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                    );
                  }
                  final childrenMap = groupTagsByParent(tags);
                  final nodes = flattenTagTree(
                    childrenMap,
                    visible: visible,
                    expanded: _expanded,
                  );
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: nodes.length,
                    itemBuilder: (context, index) => _buildRow(nodes[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 快捷标签可折叠区
  Widget _buildFavoriteSection(List<Tag> favorites, ImmichFilter filter) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _showFavorites = !_showFavorites),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Icon(Icons.star, size: 16, color: Colors.amber[700]),
                const SizedBox(width: 6),
                const Text('快捷标签', style: TextStyle(fontSize: 13)),
                const Spacer(),
                Icon(
                  _showFavorites ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
        if (_showFavorites)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 2,
              children: [
                for (final tag in favorites)
                  FilterChip(
                    label: Text(tag.name, style: const TextStyle(fontSize: 12)),
                    selected: filter.tagIds.contains(tag.id),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onSelected: (_) => ref
                        .read(immichFilterNotifierProvider.notifier)
                        .toggleTag(tag.id),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildRow(ImmichTagNode node) {
    final tag = node.tag;
    final filter = ref.watch(immichFilterNotifierProvider);
    final selected = filter.tagIds.contains(tag.id);
    final expanded = _expanded.contains(tag.id);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: EdgeInsets.only(left: node.depth * 16.0, right: 4),
      decoration: BoxDecoration(
        color: selected ? scheme.primaryContainer.withValues(alpha: 0.45) : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () =>
            ref.read(immichFilterNotifierProvider.notifier).toggleTag(tag.id),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.only(left: 4, right: 2, top: 2, bottom: 2),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: node.hasChildren
                    ? InkWell(
                        onTap: () => setState(() {
                          if (!_expanded.remove(tag.id)) _expanded.add(tag.id);
                        }),
                        borderRadius: BorderRadius.circular(12),
                        child: Icon(
                          expanded ? Icons.expand_more : Icons.chevron_right,
                          size: 18,
                          color: Colors.grey,
                        ),
                      )
                    : Icon(
                        Icons.label_outline,
                        size: 14,
                        color: Colors.grey[400],
                      ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Tooltip(
                  message: tag.fullPath ?? tag.name,
                  child: Text(
                    tag.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (tag.mediaCount > 0)
                Text(
                  '${tag.mediaCount}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              _IconTap(
                icon: tag.isFavorite ? Icons.star : Icons.star_border,
                color: tag.isFavorite ? Colors.amber : Colors.grey,
                tooltip: tag.isFavorite ? '取消快捷标签' : '设为快捷标签',
                onTap: () => _toggleFavorite(tag, !tag.isFavorite),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18),
                tooltip: '更多操作',
                padding: EdgeInsets.zero,
                onSelected: (action) => _handleMenu(action, tag),
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'add_child',
                    height: 40,
                    child: Text('添加子标签', style: TextStyle(fontSize: 13)),
                  ),
                  PopupMenuItem(
                    value: 'rename',
                    height: 40,
                    child: Text('重命名', style: TextStyle(fontSize: 13)),
                  ),
                  PopupMenuItem(
                    value: 'move_to_root',
                    height: 40,
                    child: Text('移至根级', style: TextStyle(fontSize: 13)),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    height: 40,
                    child: Text('删除',
                        style: TextStyle(fontSize: 13, color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============ 状态与操作 ============

  /// 默认展开根节点与已选标签所在路径
  void _initExpanded(List<Tag> tags, List<String> selectedIds) {
    if (_expandInitialized) return;
    _expandInitialized = true;
    final byId = {for (final tag in tags) tag.id: tag};
    final childrenMap = groupTagsByParent(tags);
    for (final root in childrenMap[''] ?? const <Tag>[]) {
      if ((childrenMap[root.id] ?? const <Tag>[]).isNotEmpty) {
        _expanded.add(root.id);
      }
    }
    for (final id in selectedIds) {
      var parentId = byId[id]?.parentId;
      while (parentId != null) {
        _expanded.add(parentId);
        parentId = byId[parentId]?.parentId;
      }
    }
  }

  void _handleMenu(String action, Tag tag) {
    switch (action) {
      case 'add_child':
        _showAddDialog(tag.id);
        break;
      case 'rename':
        _showRenameDialog(tag);
        break;
      case 'move_to_root':
        _moveToRoot(tag);
        break;
      case 'delete':
        _deleteTag(tag);
        break;
    }
  }

  Future<void> _showAddDialog(String? parentId) async {
    final name = await showImmichTextDialog(
      context,
      title: parentId == null ? '新建根标签' : '新建子标签',
      label: '标签名称',
      confirmText: '创建',
    );
    if (name == null || name.isEmpty) return;
    try {
      await ref
          .read(tagTreeProvider.notifier)
          .createTag(name: name, parentId: parentId);
      if (parentId != null && mounted) {
        setState(() => _expanded.add(parentId));
      }
    } catch (e) {
      _snack('创建失败: $e');
    }
  }

  Future<void> _showRenameDialog(Tag tag) async {
    final name = await showImmichTextDialog(
      context,
      title: '重命名标签',
      initial: tag.name,
      label: '标签名称',
    );
    if (name == null || name.isEmpty || name == tag.name) return;
    try {
      await ref.read(tagTreeProvider.notifier).renameTag(tag, name);
    } catch (e) {
      _snack('重命名失败: $e');
    }
  }

  Future<void> _moveToRoot(Tag tag) async {
    if (tag.parentId == null) {
      _snack('该标签已在根级');
      return;
    }
    try {
      await ref.read(tagTreeProvider.notifier).moveTag(tag.id, null);
      _snack('已移至根级');
    } catch (e) {
      _snack('移动失败: $e');
    }
  }

  Future<void> _deleteTag(Tag tag) async {
    final confirmed = await showImmichConfirmDialog(
      context,
      title: '删除标签',
      message: '确定删除标签 "${tag.name}" 吗?\n其子标签与媒体关联将一并删除。',
      confirmText: '删除',
      danger: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(tagTreeProvider.notifier).deleteTag(tag.id);
      if (mounted) setState(() => _expanded.remove(tag.id));
    } catch (e) {
      _snack('删除失败: $e');
    }
  }

  Future<void> _toggleFavorite(Tag tag, bool value) async {
    try {
      await ref.read(tagTreeProvider.notifier).setFavorite(tag.id, value);
    } catch (e) {
      _snack('快捷标签更新失败: $e');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }
}

/// 紧凑图标按钮
class _IconTap extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _IconTap({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}
