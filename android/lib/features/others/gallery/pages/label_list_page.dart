import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:torrid/features/others/gallery/models/tag.dart';
import 'package:torrid/features/others/gallery/providers/gallery_providers.dart';

/// 标签页
/// - 传入 [mediaId] 时为"选择标签": 点击行即为当前媒体添加/移除标签;
///   操作对象始终是"当前媒体"(currentMediaTagsProvider), 因此与画廊页实时一致.
/// - 不传 [mediaId] 时为"标签管理": 新建/重命名/删除/拖拽移动标签结构.
///
/// 长按行可拖动标签改变层级; 行尾 ★ 用于增减"快捷标签"(浮层右栏使用).
class LabelListPage extends ConsumerStatefulWidget {
  /// 媒体文件 ID，传入时支持打标签功能
  final String? mediaId;

  const LabelListPage({super.key, this.mediaId});

  @override
  ConsumerState<LabelListPage> createState() => _LabelListPageState();
}

class _LabelListPageState extends ConsumerState<LabelListPage> {
  final TextEditingController _searchController = TextEditingController();

  /// 搜索关键词（小写）
  String _query = '';

  /// 展开的标签 ID 集合
  final Set<String> _expandedIds = {};

  /// 是否已按已选标签初始化过展开状态
  bool _expandInitialized = false;

  bool get _selectMode => widget.mediaId != null;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(tagTreeProvider);
    final appliedTags = _selectMode
        ? ref.watch(currentMediaTagsProvider).valueOrNull ?? const <Tag>[]
        : const <Tag>[];
    final appliedIds = appliedTags.map((t) => t.id).toSet();
    final favoriteIds = ref.watch(galleryFavoriteTagIdsProvider).toSet();

    final allTags = tagsAsync.valueOrNull ?? const <Tag>[];
    final expandableIds = {
      for (final t in allTags)
        if (t.parentId != null) t.parentId!,
    };
    final allExpanded =
        expandableIds.isNotEmpty && _expandedIds.containsAll(expandableIds);

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectMode ? '选择标签' : '标签管理'),
        actions: [
          if (_selectMode) _buildAutoApplyToggle(),
          IconButton(
            icon: Icon(allExpanded ? Icons.unfold_less : Icons.unfold_more),
            tooltip: allExpanded ? '全部收起' : '全部展开',
            onPressed: () => _setAllExpanded(expandableIds),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '添加根标签',
            onPressed: () => _showAddTagDialog(null),
          ),
        ],
      ),
      body: tagsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('加载失败: $error'),
              ElevatedButton(
                onPressed: () => ref.invalidate(tagTreeProvider),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (tags) {
          if (tags.isEmpty) return _buildEmptyState();

          _initExpandedIds(tags, appliedIds);
          final byId = {for (final t in tags) t.id: t};

          // 搜索过滤: 命中的标签 + 其全部祖先, 保持树形结构可见
          final visible = _visibleIds(tags, byId);
          bool isVisible(Tag t) => visible == null || visible.contains(t.id);

          final childrenMap = <String, List<Tag>>{};
          for (final t in tags) {
            final parentId = t.parentId;
            if (parentId != null &&
                isVisible(t) &&
                (byId[parentId] == null || isVisible(byId[parentId]!))) {
              childrenMap.putIfAbsent(parentId, () => []).add(t);
            }
          }
          for (final list in childrenMap.values) {
            list.sort((a, b) => a.name.compareTo(b.name));
          }
          final roots = [
            for (final t in tags)
              if (t.parentId == null && isVisible(t)) t,
          ]..sort((a, b) => a.name.compareTo(b.name));

          return Column(
            children: [
              _buildSearchField(),
              if (_selectMode) _buildSelectedBar(appliedTags),
              const Divider(height: 1),
              Expanded(
                child: roots.isEmpty
                    ? const Center(
                        child: Text('未找到匹配的标签',
                            style: TextStyle(color: Colors.grey)),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: roots.length,
                        itemBuilder: (context, index) => _buildTagTile(
                          tag: roots[index],
                          childrenMap: childrenMap,
                          appliedIds: appliedIds,
                          favoriteIds: favoriteIds,
                          depth: 0,
                          forceExpand: visible != null,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ============ 顶部区域 ============

  /// 标签自动套用开关（仅在打标签模式下显示）
  Widget _buildAutoApplyToggle() {
    final isEnabled = ref.watch(galleryTagAutoApplyEnabledProvider);
    return IconButton(
      icon: Icon(
        isEnabled ? Icons.auto_fix_high : Icons.auto_fix_off,
        color: isEnabled ? Colors.blue : null,
      ),
      tooltip: isEnabled ? '自动套用: 开' : '自动套用: 关',
      onPressed: () =>
          ref.read(galleryTagAutoApplyEnabledProvider.notifier).toggle(),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '搜索标签名或路径',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                ),
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
      ),
    );
  }

  /// 已选标签区（可直观查看并快速移除）
  Widget _buildSelectedBar(List<Tag> appliedTags) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '已选 ${appliedTags.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const Spacer(),
              if (appliedTags.isNotEmpty)
                TextButton(
                  onPressed: () => ref
                      .read(currentMediaTagsProvider.notifier)
                      .setTags(const []),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('清空', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          if (appliedTags.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 92),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final tag in appliedTags)
                      InputChip(
                        label: Text(tag.name, style: const TextStyle(fontSize: 12)),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        onDeleted: () => _toggleSelection(tag.id),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.label_off_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('暂无标签', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _showAddTagDialog(null),
            icon: const Icon(Icons.add),
            label: const Text('添加标签'),
          ),
        ],
      ),
    );
  }

  // ============ 标签行 ============

  Widget _buildTagTile({
    required Tag tag,
    required Map<String, List<Tag>> childrenMap,
    required Set<String> appliedIds,
    required Set<String> favoriteIds,
    required int depth,
    required bool forceExpand,
  }) {
    final children = childrenMap[tag.id] ?? const <Tag>[];
    final hasChildren = children.isNotEmpty;
    final expanded = forceExpand || _expandedIds.contains(tag.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DragTarget<String>(
          onWillAcceptWithDetails: (details) {
            final draggedId = details.data;
            // 不能拖到自己或自己的子节点
            if (draggedId == tag.id) return false;
            return !_isDescendant(draggedId, tag.id, childrenMap);
          },
          onAcceptWithDetails: (details) => _moveTag(details.data, tag.id),
          builder: (context, candidateData, rejectedData) {
            final isDropTarget = candidateData.isNotEmpty;
            final content = _TagTileContent(
              tag: tag,
              depth: depth,
              selectMode: _selectMode,
              selected: appliedIds.contains(tag.id),
              favorite: favoriteIds.contains(tag.id),
              hasChildren: hasChildren,
              expanded: expanded,
              isDropTarget: isDropTarget,
              showPath: forceExpand,
              onTap: _selectMode
                  ? () => _toggleSelection(tag.id)
                  : (hasChildren ? () => _toggleExpand(tag.id) : null),
              onToggleExpand:
                  hasChildren ? () => _toggleExpand(tag.id) : null,
              onToggleFavorite: () => ref
                  .read(galleryFavoriteTagIdsProvider.notifier)
                  .toggle(tag.id),
              onMenuAction: (action) => _handleMenuAction(action, tag),
            );

            return LongPressDraggable<String>(
              data: tag.id,
              feedback: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.label, size: 20),
                      const SizedBox(width: 8),
                      Text(tag.name),
                    ],
                  ),
                ),
              ),
              childWhenDragging: Opacity(opacity: 0.4, child: content),
              child: content,
            );
          },
        ),
        if (expanded && hasChildren)
          for (final child in children)
            _buildTagTile(
              tag: child,
              childrenMap: childrenMap,
              appliedIds: appliedIds,
              favoriteIds: favoriteIds,
              depth: depth + 1,
              forceExpand: forceExpand,
            ),
      ],
    );
  }

  // ============ 状态操作 ============

  /// 首次进入时展开已选标签所在的路径（默认其余折叠, 避免大树难以浏览）
  void _initExpandedIds(List<Tag> tags, Set<String> appliedIds) {
    if (_expandInitialized) return;
    _expandInitialized = true;
    if (appliedIds.isEmpty) return;

    final byId = {for (final t in tags) t.id: t};
    for (final id in appliedIds) {
      var parentId = byId[id]?.parentId;
      while (parentId != null) {
        _expandedIds.add(parentId);
        parentId = byId[parentId]?.parentId;
      }
    }
  }

  void _setAllExpanded(Set<String> expandableIds) {
    setState(() {
      if (_expandedIds.containsAll(expandableIds)) {
        _expandedIds.clear();
      } else {
        _expandedIds.addAll(expandableIds);
      }
    });
  }

  /// 搜索命中集合（null 表示未搜索）
  Set<String>? _visibleIds(List<Tag> tags, Map<String, Tag> byId) {
    if (_query.isEmpty) return null;
    final keep = <String>{};
    for (final tag in tags) {
      final matched = tag.name.toLowerCase().contains(_query) ||
          (tag.fullPath ?? '').toLowerCase().contains(_query);
      if (!matched) continue;
      keep.add(tag.id);
      var parentId = tag.parentId;
      while (parentId != null) {
        if (!keep.add(parentId)) break;
        parentId = byId[parentId]?.parentId;
      }
    }
    return keep;
  }

  void _toggleExpand(String tagId) {
    setState(() {
      if (!_expandedIds.remove(tagId)) _expandedIds.add(tagId);
    });
  }

  /// 切换选中状态（打标签模式下立即写入）
  Future<void> _toggleSelection(String tagId) async {
    final current = (ref.read(currentMediaTagsProvider).valueOrNull ??
            const <Tag>[])
        .map((t) => t.id)
        .toList();
    if (!current.remove(tagId)) current.add(tagId);
    try {
      await ref.read(currentMediaTagsProvider.notifier).setTags(current);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失败: $e')));
      }
    }
  }

  // ============ 标签结构编辑 ============

  void _handleMenuAction(String action, Tag tag) {
    switch (action) {
      case 'add_child':
        _showAddTagDialog(tag.id);
        break;
      case 'rename':
        _showRenameDialog(tag);
        break;
      case 'move_to_root':
        _moveTag(tag.id, null);
        break;
      case 'delete':
        _showDeleteConfirmDialog(tag);
        break;
    }
  }

  /// 显示添加标签对话框
  Future<void> _showAddTagDialog(String? parentId) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _TagNameDialog(
        title: parentId == null ? '添加根标签' : '添加子标签',
      ),
    );
    if (name != null && name.isNotEmpty) {
      await _addTag(name, parentId);
    }
  }

  /// 添加标签
  Future<void> _addTag(String name, String? parentId) async {
    final allTags = ref.read(tagTreeProvider).valueOrNull ?? [];

    String fullPath;
    if (parentId == null) {
      fullPath = name;
    } else {
      final parent = allTags.firstWhere((t) => t.id == parentId);
      fullPath = '${parent.fullPath}/$name';
    }

    final now = DateTime.now();
    final tag = Tag(
      id: const Uuid().v4(),
      createdAt: now,
      updatedAt: now,
      name: name,
      parentId: parentId,
      fullPath: fullPath,
    );

    try {
      await ref.read(tagTreeProvider.notifier).addTag(tag);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('添加失败: $e')));
      }
      return;
    }

    // 展开父节点
    if (parentId != null && mounted) {
      setState(() => _expandedIds.add(parentId));
    }
  }

  /// 显示重命名对话框
  Future<void> _showRenameDialog(Tag tag) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _TagNameDialog(title: '重命名标签', initialText: tag.name),
    );
    if (name == null || name.isEmpty || name == tag.name) return;

    final allTags = ref.read(tagTreeProvider).valueOrNull ?? [];
    Tag? parent;
    for (final t in allTags) {
      if (t.id == tag.parentId) {
        parent = t;
        break;
      }
    }

    final updatedTag = tag.copyWith(
      name: name,
      fullPath: parent == null ? name : '${parent.fullPath}/$name',
      updatedAt: DateTime.now(),
    );

    try {
      await ref.read(tagTreeProvider.notifier).updateTag(updatedTag);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('重命名失败: $e')));
      }
    }
  }

  /// 显示删除确认对话框
  Future<void> _showDeleteConfirmDialog(Tag tag) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除标签'),
        content: Text('确定要删除标签 "${tag.name}" 吗？\n子标签将一并删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(tagTreeProvider.notifier).deleteTag(tag.id);
      if (mounted) setState(() => _expandedIds.remove(tag.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('删除失败: $e')));
      }
    }
  }

  /// 移动标签
  Future<void> _moveTag(String tagId, String? newParentId) async {
    try {
      await ref.read(tagTreeProvider.notifier).moveTag(tagId, newParentId);
      if (newParentId != null && mounted) {
        setState(() => _expandedIds.add(newParentId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('移动失败: $e')));
      }
    }
  }

  /// 检查 [descendantId] 是否为 [ancestorId] 的子孙
  bool _isDescendant(
    String ancestorId,
    String descendantId,
    Map<String, List<Tag>> childrenMap,
  ) {
    final children = childrenMap[ancestorId] ?? const <Tag>[];
    for (final child in children) {
      if (child.id == descendantId) return true;
      if (_isDescendant(child.id, descendantId, childrenMap)) return true;
    }
    return false;
  }
}

/// 标签行内容
class _TagTileContent extends StatelessWidget {
  final Tag tag;
  final int depth;
  final bool selectMode;
  final bool selected;
  final bool favorite;
  final bool hasChildren;
  final bool expanded;
  final bool isDropTarget;
  final bool showPath;
  final VoidCallback? onTap;
  final VoidCallback? onToggleExpand;
  final VoidCallback onToggleFavorite;
  final void Function(String action) onMenuAction;

  const _TagTileContent({
    required this.tag,
    required this.depth,
    required this.selectMode,
    required this.selected,
    required this.favorite,
    required this.hasChildren,
    required this.expanded,
    required this.isDropTarget,
    required this.showPath,
    required this.onToggleFavorite,
    required this.onMenuAction,
    this.onTap,
    this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: EdgeInsets.only(left: depth * 20.0, right: 4),
      decoration: BoxDecoration(
        color: isDropTarget
            ? scheme.primaryContainer.withValues(alpha: 0.3)
            : (selected ? scheme.primaryContainer.withValues(alpha: 0.45) : null),
        border: isDropTarget
            ? Border.all(color: scheme.primary, width: 2)
            : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.only(left: 8, right: 2, top: 2, bottom: 2),
          child: Row(
            children: [
              if (selectMode)
                Icon(
                  selected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: selected ? scheme.primary : Colors.grey,
                )
              else
                Icon(
                  hasChildren ? Icons.folder : Icons.label,
                  size: 18,
                  color: hasChildren ? Colors.amber : Colors.grey,
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tag.name,
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (showPath && tag.fullPath != null && tag.fullPath != tag.name)
                      Text(
                        tag.fullPath!,
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              _IconTap(
                icon: favorite ? Icons.star : Icons.star_border,
                color: favorite ? Colors.amber : Colors.grey,
                tooltip: favorite ? '取消快捷标签' : '设为快捷标签',
                onTap: onToggleFavorite,
              ),
              if (hasChildren)
                _IconTap(
                  icon: expanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.grey,
                  tooltip: expanded ? '收起' : '展开',
                  onTap: onToggleExpand,
                ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                tooltip: '更多操作',
                padding: EdgeInsets.zero,
                onSelected: onMenuAction,
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'add_child',
                    child: ListTile(
                      leading: Icon(Icons.add),
                      title: Text('添加子标签'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'rename',
                    child: ListTile(
                      leading: Icon(Icons.edit),
                      title: Text('重命名'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'move_to_root',
                    child: ListTile(
                      leading: Icon(Icons.move_up),
                      title: Text('移至根级'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete, color: Colors.red),
                      title: Text('删除', style: TextStyle(color: Colors.red)),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 紧凑图标按钮
class _IconTap extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;

  const _IconTap({
    required this.icon,
    required this.color,
    required this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

/// 标签命名对话框（自持控制器，避免异步销毁问题）
class _TagNameDialog extends StatefulWidget {
  final String title;
  final String? initialText;

  const _TagNameDialog({required this.title, this.initialText});

  @override
  State<_TagNameDialog> createState() => _TagNameDialogState();
}

class _TagNameDialogState extends State<_TagNameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialText ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: '标签名称',
          hintText: '请输入标签名称',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('确定')),
      ],
    );
  }
}
