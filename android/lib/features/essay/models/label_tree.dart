import 'package:torrid/features/essay/models/essay.dart';
import 'package:torrid/features/essay/models/label.dart';

void validateLabelTree(Iterable<Label> labels) {
  final byId = {for (final label in labels) label.id: label};
  for (final label in labels) {
    if (label.id.isEmpty || label.name.trim().isEmpty) {
      throw const FormatException('标签缺少 ID 或名称');
    }
    if (label.id == Label.hiddenId &&
        (label.name != '隐藏' || label.parentId != null)) {
      throw const FormatException('隐藏标签必须保留在根级');
    }
    final seen = {label.id};
    var parentId = label.parentId;
    while (parentId != null) {
      if (!seen.add(parentId)) throw const FormatException('标签不能循环嵌套');
      final parent = byId[parentId];
      if (parent == null) throw const FormatException('上级标签不存在');
      parentId = parent.parentId;
    }
  }
}

Set<String> labelSubtree(Iterable<Label> labels, Iterable<String> roots) {
  final children = _labelsByParent(labels);
  final result = roots.toSet();
  final pending = result.toList();
  while (pending.isNotEmpty) {
    for (final child in children[pending.removeLast()] ?? const <Label>[]) {
      if (result.add(child.id)) pending.add(child.id);
    }
  }
  return result;
}

Set<String> hiddenLabelIds(Iterable<Label> labels) => labelSubtree(labels, {
  Label.hiddenId,
  ...labels.where((l) => l.isHiddenRoot).map((l) => l.id),
});

List<Essay> visibleEssays(Iterable<Essay> essays, Iterable<Label> labels) {
  final hidden = hiddenLabelIds(labels);
  return essays.where((essay) => !essay.labels.any(hidden.contains)).toList();
}

List<Label> countEssayLabels(Iterable<Essay> essays, Iterable<Label> labels) {
  final byId = {for (final label in labels) label.id: label};
  final children = _labelsByParent(byId.values);
  final roots = <String, String>{};
  for (final root in children[null] ?? const <Label>[]) {
    final pending = [root];
    while (pending.isNotEmpty) {
      final label = pending.removeLast();
      roots[label.id] = root.id;
      if (children[label.id] case final descendants?) {
        pending.addAll(descendants);
      }
    }
  }
  final counts = <String, int>{};
  for (final essay in essays) {
    final linked = {
      ...essay.labels,
      for (final id in essay.labels)
        if (roots[id] case final root?) root,
    };
    for (final id in linked) {
      counts[id] = (counts[id] ?? 0) + 1;
    }
  }
  return [
    for (final label in byId.values)
      label.copyWith(essayCount: counts[label.id] ?? 0),
  ];
}

Map<String, String> labelPaths(Iterable<Label> labels) {
  final byId = {for (final label in labels) label.id: label};
  return {for (final label in byId.values) label.id: _labelPath(label, byId)};
}

String _labelPath(Label label, Map<String, Label> byId) {
  final parts = <String>[];
  final seen = <String>{};
  Label? item = label;
  while (item != null && seen.add(item.id)) {
    parts.add(item.name);
    item = byId[item.parentId];
  }
  return parts.reversed.join(' / ');
}

Map<String?, List<Label>> _labelsByParent(Iterable<Label> labels) {
  final children = <String?, List<Label>>{};
  for (final label in labels) {
    children.putIfAbsent(label.parentId, () => []).add(label);
  }
  return children;
}

List<({Label label, int depth})> flattenLabels(
  Iterable<Label> labels, {
  Set<String>? expanded,
  String query = '',
}) {
  final needle = query.trim().toLowerCase();
  Set<String>? visible;
  if (needle.isNotEmpty) {
    visible = <String>{};
    final byId = {for (final label in labels) label.id: label};
    final paths = labelPaths(labels);
    for (final label in labels) {
      if (!paths[label.id]!.toLowerCase().contains(needle)) continue;
      Label? current = label;
      while (current != null && visible.add(current.id)) {
        current = byId[current.parentId];
      }
    }
  }
  final children = _labelsByParent(labels);
  for (final siblings in children.values) {
    siblings.sort((a, b) {
      final count = b.essayCount.compareTo(a.essayCount);
      return count != 0 ? count : a.name.compareTo(b.name);
    });
  }
  final result = <({Label label, int depth})>[];
  final visited = <String>{};
  void walk(String? parent, int depth) {
    for (final label in children[parent] ?? <Label>[]) {
      if (visible != null && !visible.contains(label.id)) continue;
      if (!visited.add(label.id)) continue;
      result.add((label: label, depth: depth));
      if (visible != null || expanded == null || expanded.contains(label.id)) {
        walk(label.id, depth + 1);
      }
    }
  }

  walk(null, 0);
  return result;
}
