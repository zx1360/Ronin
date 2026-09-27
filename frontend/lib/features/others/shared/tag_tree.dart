import 'package:torrid/features/others/gallery/models/tag.dart';

/// 扁平标签列表的树形索引
///
/// 一次性算好 id 查找、父级分组、根级列表与可展开 id 集合;
/// 各标签页只做渲染与交互, 不再各自重算树结构.
class TagTreeIndex {
  TagTreeIndex(List<Tag> tags)
      : _tags = List<Tag>.unmodifiable(tags),
        _byId = {},
        _childrenByParentId = {},
        _roots = [],
        _expandableIds = {} {
    for (final tag in tags) {
      _byId[tag.id] = tag;
    }
    for (final tag in tags) {
      final parentId = tag.parentId;
      // 父级不存在(或根本没有父级)的标签归到 '' 键下, 由调用方决定是否当作根级
      final key =
          (parentId != null && _byId.containsKey(parentId)) ? parentId : '';
      _childrenByParentId.putIfAbsent(key, () => <Tag>[]).add(tag);
      if (parentId != null) _expandableIds.add(parentId);
      if (parentId == null) _roots.add(tag);
    }
    for (final list in _childrenByParentId.values) {
      list.sort(_byName);
    }
    _roots.sort(_byName);
  }

  final List<Tag> _tags;
  final Map<String, Tag> _byId;
  final Map<String, List<Tag>> _childrenByParentId;
  final List<Tag> _roots;
  final Set<String> _expandableIds;

  /// id → 标签
  Map<String, Tag> get byId => _byId;

  /// 根标签 (parentId 为 null), 按名称排序
  List<Tag> get roots => _roots;

  /// 根级展示列表: 真根 + 父级缺失的孤儿, 按 (fullPath ?? name) 排序.
  ///
  /// 各标签视图一律用这个而不是 [roots]: 父标签被删后子标签会成为孤儿,
  /// 若把它们丢掉, 这些标签就会从界面上消失、再也没法处理.
  List<Tag> get displayRoots {
    final list = [...?_childrenByParentId['']];
    list.sort(_byPath);
    return list;
  }

  /// 父级 id → 子标签 (按名称排序); 父级缺失的标签放在 '' 键下
  Map<String, List<Tag>> get childrenByParentId => _childrenByParentId;

  /// 是否存在子级
  bool hasChildren(String id) => _childrenByParentId.containsKey(id);

  /// 父级 id; 标签不存在或已是根级时为 null
  String? parentIdOf(String id) => _byId[id]?.parentId;

  /// 全部祖先 (不含自身), 沿 parentId 向上回溯, 遇环即止
  Set<String> ancestorsOf(String id) {
    final result = <String>{};
    var parentId = _byId[id]?.parentId;
    while (parentId != null) {
      if (!result.add(parentId)) break; // 环保护
      parentId = _byId[parentId]?.parentId;
    }
    return result;
  }

  /// [ancestorId] 是否为 [descendantId] 的严格祖先 (沿 parentId 向上, 环安全)
  bool isAncestorOf(String ancestorId, String descendantId) {
    final seen = <String>{};
    var parentId = _byId[descendantId]?.parentId;
    while (parentId != null) {
      if (parentId == ancestorId) return true;
      if (!seen.add(parentId)) return false; // 环保护
      parentId = _byId[parentId]?.parentId;
    }
    return false;
  }

  /// 出现过父级的 id 集合 (用于"全部展开/收起")
  Set<String> get expandableIds => _expandableIds;

  /// 搜索命中集合: 名称或路径包含 [query] 的标签 + 其全部祖先;
  /// [query] 为空时返回 null (表示未搜索)
  Set<String>? matchingIdsWithAncestors(String query) {
    if (query.isEmpty) return null;
    final lower = query.toLowerCase();
    final keep = <String>{};
    for (final tag in _tags) {
      final hit = tag.name.toLowerCase().contains(lower) ||
          (tag.fullPath ?? '').toLowerCase().contains(lower);
      if (!hit) continue;
      keep.add(tag.id);
      keep.addAll(ancestorsOf(tag.id));
    }
    return keep;
  }

  /// 全部标签按 (fullPath ?? name) 排序
  List<Tag> sortedByPath() => [..._tags]..sort(_byPath);

  static int _byName(Tag a, Tag b) => a.name.compareTo(b.name);

  static int _byPath(Tag a, Tag b) =>
      (a.fullPath ?? a.name).compareTo(b.fullPath ?? b.name);
}
