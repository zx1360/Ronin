import 'package:torrid/features/essay/models/essay.dart';
import 'package:torrid/features/essay/models/label.dart';

List<Label> ensureHiddenLabel(Iterable<Label> labels) {
  final result = labels.toList();
  if (!result.any((label) => label.isHiddenRoot)) result.add(Label.hidden());
  return result;
}

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
  final byId = {for (final label in labels) label.id: label};
  final result = roots.toSet();
  for (final label in labels) {
    final seen = <String>{};
    String? id = label.id;
    while (id != null && seen.add(id)) {
      if (result.contains(id)) {
        result.add(label.id);
        break;
      }
      id = byId[id]?.parentId;
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

String labelPath(Label label, Iterable<Label> labels) {
  final byId = {for (final item in labels) item.id: item};
  final parts = <String>[];
  final seen = <String>{};
  Label? item = label;
  while (item != null && seen.add(item.id)) {
    parts.add(item.name);
    item = byId[item.parentId];
  }
  return parts.reversed.join(' / ');
}

List<({Label label, int depth})> flattenLabels(Iterable<Label> labels) {
  final children = <String?, List<Label>>{};
  for (final label in labels) {
    children.putIfAbsent(label.parentId, () => []).add(label);
  }
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
      if (!visited.add(label.id)) continue;
      result.add((label: label, depth: depth));
      walk(label.id, depth + 1);
    }
  }

  walk(null, 0);
  return result;
}
