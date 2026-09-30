import 'package:flutter_test/flutter_test.dart';
import 'package:torrid/features/others/gallery/models/tag.dart';
import 'package:torrid/features/others/gallery/models/tag_tree.dart';

final _epoch = DateTime(2026, 1, 1);

Tag tag(String id, String name, {String? parentId, String? fullPath}) => Tag(
      id: id,
      createdAt: _epoch,
      updatedAt: _epoch,
      name: name,
      parentId: parentId,
      fullPath: fullPath ?? name,
    );

/// 一棵固定的小树：
///   读书 ── 技术 ── 论文
///   生活
///   (孤儿: 父级已被删除)
void main() {
  final tags = [
    tag('root1', '读书'),
    tag('root2', '生活'),
    tag('child1', '技术', parentId: 'root1', fullPath: '读书/技术'),
    tag('leaf1', '论文', parentId: 'child1', fullPath: '读书/技术/论文'),
    tag('orphan', '孤儿', parentId: 'ghost', fullPath: '孤儿'),
  ];

  group('groupTagsByParent', () {
    test('根级 key 为空串，父级不存在的标签归到根级', () {
      final map = groupTagsByParent(tags);
      expect(map['']!.map((t) => t.id), containsAll(['root1', 'root2', 'orphan']));
      expect(map['root1']!.map((t) => t.id), ['child1']);
      expect(map['child1']!.map((t) => t.id), ['leaf1']);
      expect(rootTags(map).length, 3, reason: '孤儿不能从界面上消失');
    });

    test('同级按名称排序，可换成按路径排序', () {
      final items = [
        tag('x', 'B'),
        tag('y', 'A'),
      ];
      expect(groupTagsByParent(items)['']!.map((t) => t.id), ['y', 'x']);
      expect(
        groupTagsByParent(items, compare: compareTagsByPath)['']!
            .map((t) => t.id),
        ['y', 'x'],
      );
    });

    test('名称相同的兄弟节点按完整路径区分先后', () {
      final items = [
        tag('b', 'same', fullPath: 'B/same'),
        tag('a', 'same', fullPath: 'A/same'),
      ];
      expect(
        groupTagsByParent(items, compare: compareTagsByPath)['']!
            .map((t) => t.id),
        ['a', 'b'],
      );
    });
  });

  group('flattenTagTree', () {
    test('默认只展开已展开的节点', () {
      final nodes = flattenTagTree(groupTagsByParent(tags));
      expect(nodes.map((n) => n.tag.id), containsAll(['root1', 'root2', 'orphan']));
      expect(nodes.map((n) => n.tag.id), isNot(contains('child1')));
      expect(nodes.firstWhere((n) => n.tag.id == 'root1').hasChildren, isTrue);
      expect(nodes.firstWhere((n) => n.tag.id == 'root2').hasChildren, isFalse);
    });

    test('展开后深度递增', () {
      final nodes = flattenTagTree(
        groupTagsByParent(tags),
        expanded: {'root1', 'child1'},
      );
      expect(nodes.map((n) => n.tag.id),
          containsAll(['root1', 'child1', 'leaf1', 'root2', 'orphan']));
      expect(nodes.firstWhere((n) => n.tag.id == 'leaf1').depth, 2);
    });

    test('搜索态强制展开且只保留可见项', () {
      final map = groupTagsByParent(tags);
      final visible = matchedTagIds(tags, '论文');
      final nodes = flattenTagTree(map, visible: visible);
      expect(nodes.map((n) => n.tag.id),
          containsAll(['root1', 'child1', 'leaf1']));
      expect(nodes.map((n) => n.tag.id), isNot(contains('root2')));
    });
  });

  group('matchedTagIds', () {
    test('命中项连同全部祖先一起保留', () {
      expect(matchedTagIds(tags, '论文'), {'leaf1', 'child1', 'root1'});
    });

    test('忽略大小写与首尾空白', () {
      expect(matchedTagIds(tags, '  读书  '), contains('root1'));
    });

    test('空查询返回空集合', () {
      expect(matchedTagIds(tags, '   '), isEmpty);
    });

    test('按完整路径也能命中', () {
      expect(matchedTagIds(tags, '读书/技术'), containsAll(['root1', 'child1']));
    });
  });

  group('祖先判断', () {
    test('ancestorIds 由近及远', () {
      expect(ancestorIds(tagIndex(tags), 'leaf1'), {'child1', 'root1'});
      expect(ancestorIds(tagIndex(tags), 'root1'), isEmpty);
    });

    test('数据成环时不会死循环', () {
      final cyclic = [
        tag('a', 'A', parentId: 'b'),
        tag('b', 'B', parentId: 'a'),
      ];
      expect(ancestorIds(tagIndex(cyclic), 'a'), {'b', 'a'});
    });

    test('isAncestorOf 含自身', () {
      final byId = tagIndex(tags);
      expect(isAncestorOf(byId, 'root1', 'leaf1'), isTrue);
      expect(isAncestorOf(byId, 'leaf1', 'root1'), isFalse);
      expect(isAncestorOf(byId, 'root1', 'root1'), isTrue);
      expect(isAncestorOf(byId, 'root1', 'root2'), isFalse);
    });
  });
}
