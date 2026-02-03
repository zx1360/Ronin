import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:torrid/features/others/gallery/models/tag.dart';
import 'package:torrid/features/others/gallery/providers/gallery_providers.dart';

/// 折叠式树形标签列表组件
/// - 展示本地 sqflite 数据库中 tags 表的树状标签
/// - 支持标签的更名、添加、删除、拖拽移动
/// - 传入 mediaId 时，支持为该媒体文件打标签
class LabelListPage extends ConsumerStatefulWidget {
  /// 媒体文件 ID，传入时支持打标签功能
  final String? mediaId;

  const LabelListPage({
    super.key,
    this.mediaId,
  });

  @override
  ConsumerState<LabelListPage> createState() => _LabelListPageState();
}

class _LabelListPageState extends ConsumerState<LabelListPage> {
  /// 展开的标签 ID 集合
  final Set<String> _expandedIds = {};
  
  /// 选中的标签 ID 集合 (用于打标签)
  Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    // 如果有 mediaId，加载已关联的标签
    if (widget.mediaId != null) {
      _loadSelectedTags();
    }
  }

  Future<void> _loadSelectedTags() async {
    final db = ref.read(galleryDatabaseProvider);
    final tagIds = await db.getTagIdsForMedia(widget.mediaId!);
    setState(() {
      _selectedIds = tagIds.toSet();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(tagTreeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mediaId != null ? '选择标签' : '标签管理'),
        actions: [
          // 添加根标签按钮
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '添加根标签',
            onPressed: () => _showAddTagDialog(null),
          ),
          // 如果是打标签模式，显示确认按钮
          if (widget.mediaId != null)
            IconButton(
              icon: const Icon(Icons.check),
              tooltip: '确认',
              onPressed: _confirmSelection,
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
          if (tags.isEmpty) {
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

          // 构建树形结构
          final rootTags = tags.where((t) => t.parentId == null).toList();
          final tagMap = {for (var t in tags) t.id: t};
          final childrenMap = <String, List<Tag>>{};
          
          for (final tag in tags) {
            if (tag.parentId != null) {
              childrenMap.putIfAbsent(tag.parentId!, () => []).add(tag);
            }
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: rootTags.length,
            itemBuilder: (context, index) {
              return _buildTagTile(
                tag: rootTags[index],
                tagMap: tagMap,
                childrenMap: childrenMap,
                depth: 0,
              );
            },
          );
        },
      ),
    );
  }

  /// 构建单个标签项
  Widget _buildTagTile({
    required Tag tag,
    required Map<String, Tag> tagMap,
    required Map<String, List<Tag>> childrenMap,
    required int depth,
  }) {
    final children = childrenMap[tag.id] ?? [];
    final hasChildren = children.isNotEmpty;
    final isExpanded = _expandedIds.contains(tag.id);
    final isSelected = _selectedIds.contains(tag.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 拖拽目标
        DragTarget<String>(
          onWillAcceptWithDetails: (details) {
            final draggedId = details.data;
            // 不能拖到自己或自己的子节点
            if (draggedId == tag.id) return false;
            if (_isDescendant(draggedId, tag.id, childrenMap)) return false;
            return true;
          },
          onAcceptWithDetails: (details) {
            _moveTag(details.data, tag.id);
          },
          builder: (context, candidateData, rejectedData) {
            final isDropTarget = candidateData.isNotEmpty;
            
            return LongPressDraggable<String>(
              data: tag.id,
              feedback: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              childWhenDragging: Opacity(
                opacity: 0.5,
                child: _buildTagContent(
                  tag: tag,
                  depth: depth,
                  hasChildren: hasChildren,
                  isExpanded: isExpanded,
                  isSelected: isSelected,
                  isDropTarget: false,
                ),
              ),
              child: _buildTagContent(
                tag: tag,
                depth: depth,
                hasChildren: hasChildren,
                isExpanded: isExpanded,
                isSelected: isSelected,
                isDropTarget: isDropTarget,
              ),
            );
          },
        ),
        
        // 子标签
        if (isExpanded && hasChildren)
          ...children.map((child) => _buildTagTile(
                tag: child,
                tagMap: tagMap,
                childrenMap: childrenMap,
                depth: depth + 1,
              )),
      ],
    );
  }

  /// 构建标签内容
  Widget _buildTagContent({
    required Tag tag,
    required int depth,
    required bool hasChildren,
    required bool isExpanded,
    required bool isSelected,
    required bool isDropTarget,
  }) {
    return Container(
      margin: EdgeInsets.only(left: depth * 24.0),
      decoration: BoxDecoration(
        color: isDropTarget
            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
            : isSelected
                ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5)
                : null,
        border: isDropTarget
            ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
            : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: widget.mediaId != null
            ? Checkbox(
                value: isSelected,
                onChanged: (value) => _toggleSelection(tag.id),
              )
            : Icon(
                hasChildren ? Icons.folder : Icons.label,
                color: hasChildren ? Colors.amber : Colors.grey,
              ),
        title: Text(tag.name),
        subtitle: tag.fullPath != null && tag.fullPath != tag.name
            ? Text(
                tag.fullPath!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 展开/收起按钮
            if (hasChildren)
              IconButton(
                icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                onPressed: () => _toggleExpand(tag.id),
              ),
            // 更多操作菜单
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) => _handleMenuAction(value, tag),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'add_child',
                  child: ListTile(
                    leading: Icon(Icons.add),
                    title: Text('添加子标签'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'rename',
                  child: ListTile(
                    leading: Icon(Icons.edit),
                    title: Text('重命名'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'move_to_root',
                  child: ListTile(
                    leading: Icon(Icons.move_up),
                    title: Text('移至根级'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete, color: Colors.red),
                    title: Text('删除', style: TextStyle(color: Colors.red)),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: widget.mediaId != null
            ? () => _toggleSelection(tag.id)
            : hasChildren
                ? () => _toggleExpand(tag.id)
                : null,
      ),
    );
  }

  /// 切换展开状态
  void _toggleExpand(String tagId) {
    setState(() {
      if (_expandedIds.contains(tagId)) {
        _expandedIds.remove(tagId);
      } else {
        _expandedIds.add(tagId);
      }
    });
  }

  /// 切换选中状态
  void _toggleSelection(String tagId) {
    setState(() {
      if (_selectedIds.contains(tagId)) {
        _selectedIds.remove(tagId);
      } else {
        _selectedIds.add(tagId);
      }
    });
  }

  /// 确认选择
  Future<void> _confirmSelection() async {
    if (widget.mediaId == null) return;
    
    await ref.read(currentMediaTagsProvider.notifier).setTags(_selectedIds.toList());
    
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('标签已更新')),
      );
    }
  }

  /// 处理菜单操作
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
    final controller = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(parentId == null ? '添加根标签' : '添加子标签'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '标签名称',
            hintText: '请输入标签名称',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _addTag(result, parentId);
    }
  }

  /// 添加标签
  Future<void> _addTag(String name, String? parentId) async {
    final allTags = ref.read(tagTreeProvider).valueOrNull ?? [];
    
    // 计算 full_path
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

    await ref.read(tagTreeProvider.notifier).addTag(tag);
    
    // 展开父节点
    if (parentId != null) {
      setState(() {
        _expandedIds.add(parentId);
      });
    }
  }

  /// 显示重命名对话框
  Future<void> _showRenameDialog(Tag tag) async {
    final controller = TextEditingController(text: tag.name);
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名标签'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '标签名称',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != tag.name) {
      // 计算新的 full_path
      String newFullPath;
      if (tag.parentId == null) {
        newFullPath = result;
      } else {
        final allTags = ref.read(tagTreeProvider).valueOrNull ?? [];
        final parent = allTags.firstWhere((t) => t.id == tag.parentId);
        newFullPath = '${parent.fullPath}/$result';
      }

      final updatedTag = tag.copyWith(
        name: result,
        fullPath: newFullPath,
        updatedAt: DateTime.now(),
      );
      
      await ref.read(tagTreeProvider.notifier).updateTag(updatedTag);
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

    if (confirmed == true) {
      await ref.read(tagTreeProvider.notifier).deleteTag(tag.id);
      setState(() {
        _selectedIds.remove(tag.id);
        _expandedIds.remove(tag.id);
      });
    }
  }

  /// 移动标签
  Future<void> _moveTag(String tagId, String? newParentId) async {
    try {
      await ref.read(tagTreeProvider.notifier).moveTag(tagId, newParentId);
      
      // 展开新父节点
      if (newParentId != null) {
        setState(() {
          _expandedIds.add(newParentId);
        });
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('标签已移动')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('移动失败: $e')),
        );
      }
    }
  }

  /// 检查是否为子节点
  bool _isDescendant(
    String ancestorId,
    String descendantId,
    Map<String, List<Tag>> childrenMap,
  ) {
    final children = childrenMap[ancestorId] ?? [];
    for (final child in children) {
      if (child.id == descendantId) return true;
      if (_isDescendant(child.id, descendantId, childrenMap)) return true;
    }
    return false;
  }
}