/// 标签树的公共工具：分组、扁平化、搜索命中与祖先判断。
///
/// 相册页(immich)、标签列表页与快速打标签浮层共用这一份：遍历与排序规则很容易
/// 走偏（例如把被过滤掉的中间层误判为可放置目标而形成树环）。
library;

import 'package:torrid/features/others/gallery/models/tag.dart';

/// 同级排序：按名称。
int compareTagsByName(Tag a, Tag b) => a.name.compareTo(b.name);

/// 同级排序：按完整路径（层级内等价于按名称，跨层时更符合阅读顺序）。
int compareTagsByPath(Tag a, Tag b) =>
    (a.fullPath ?? a.name).compareTo(b.fullPath ?? b.name);

/// 扁平化后的树节点。
class TagNode {
  final Tag tag;
  final int depth;
  final bool hasChildren;

  const TagNode({
    required this.tag,
    required this.depth,
    required this.hasChildren,
  });
}

/// 按父级分组，根级的 key 为 `''`。
///
/// 父级不存在的标签（父级已被删除等）归到根级，否则整棵子树会从界面上消失。
Map<String, List<Tag>> groupTagsByParent(
  List<Tag> tags, {
  int Function(Tag, Tag) compare = compareTagsByName,
}) {
  final byId = {for (final tag in tags) tag.id: tag};
  final map = <String, List<Tag>>{};
  for (final tag in tags) {
    final parentId = tag.parentId;
    final key =
        (parentId != null && byId.containsKey(parentId)) ? parentId : '';
    map.putIfAbsent(key, () => []).add(tag);
  }
  for (final list in map.values) {
    list.sort(compare);
  }
  return map;
}

/// 根级标签列表。
List<Tag> rootTags(Map<String, List<Tag>> childrenMap) =>
    childrenMap[''] ?? const [];

/// 扁平化标签树；[visible] 非空时仅保留其中的标签并强制展开（搜索态）。
List<TagNode> flattenTagTree(
  Map<String, List<Tag>> childrenMap, {
  Set<String>? visible,
  Set<String> expanded = const {},
}) {
  final result = <TagNode>[];
  void walk(String parentKey, int depth) {
    for (final tag in childrenMap[parentKey] ?? const <Tag>[]) {
      if (visible != null && !visible.contains(tag.id)) continue;
      final hasChildren = (childrenMap[tag.id] ?? const <Tag>[]).isNotEmpty;
      result.add(TagNode(tag: tag, depth: depth, hasChildren: hasChildren));
      if (hasChildren && (visible != null || expanded.contains(tag.id))) {
        walk(tag.id, depth + 1);
      }
    }
  }

  walk('', 0);
  return result;
}

/// id → Tag 索引（树遍历类工具都基于它，调用方通常已有该索引）。
Map<String, Tag> tagIndex(List<Tag> tags) =>
    {for (final tag in tags) tag.id: tag};

/// 搜索命中的标签 id 及其全部祖先；空查询返回空集合。
///
/// 大小写与首尾空白在这里统一处理，调用方直接传输入框原文即可。
Set<String> matchedTagIds(List<Tag> tags, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return {};
  final byId = tagIndex(tags);
  final keep = <String>{};
  for (final tag in tags) {
    final hit = tag.name.toLowerCase().contains(needle) ||
        (tag.fullPath ?? '').toLowerCase().contains(needle);
    if (!hit) continue;
    keep.add(tag.id);
    keep.addAll(ancestorIds(byId, tag.id));
  }
  return keep;
}

/// [tagId] 的全部祖先 id。
Set<String> ancestorIds(Map<String, Tag> byId, String tagId) {
  final result = <String>{};
  var parentId = byId[tagId]?.parentId;
  while (parentId != null) {
    if (!result.add(parentId)) break; // 数据成环时止损
    parentId = byId[parentId]?.parentId;
  }
  return result;
}

/// [ancestorId] 是否为 [descendantId] 的祖先（同一个 id 视为真）。
///
/// 沿 parentId 向上回溯，而不是遍历（可能被搜索过滤过的）分组结果——
/// 否则过滤掉中间层级后会把子孙误判为合法落点，从而形成树环。
bool isAncestorOf(
  Map<String, Tag> byId,
  String ancestorId,
  String descendantId,
) {
  if (ancestorId == descendantId) return true;
  return ancestorIds(byId, descendantId).contains(ancestorId);
}
