// 临时回归测试：标签浮层在"未旋转 / 媒体旋转 90°"两种方向下都能完成首帧布局。
//
// 背景：浮层旋转后构建期读取自身 RenderBox 的 size 会触发
// 'hasSize': RenderBox was not laid out 断言，导致快速打标签完全不可用。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torrid/features/others/gallery/models/tag.dart';
import 'package:torrid/features/others/gallery/providers/tag_providers.dart';
import 'package:torrid/features/others/gallery/widgets/tag_drag_overlay.dart';

/// 假的标签树：只需要浮层能取到标签数据。
class _FakeTagTree extends TagTree {
  @override
  Future<List<Tag>> build() async {
    final now = DateTime(2026, 1, 1);
    return [
      Tag(id: 'root', createdAt: now, updatedAt: now, name: '家人', fullPath: '家人'),
      Tag(
        id: 'child',
        createdAt: now,
        updatedAt: now,
        name: '小猫',
        parentId: 'root',
        fullPath: '家人/小猫',
        isFavorite: true,
      ),
    ];
  }
}

/// 假的"当前媒体标签"：浮层只读取已应用集合。
class _FakeCurrentMediaTags extends CurrentMediaTags {
  @override
  Future<List<Tag>> build() async => const [];
}

Widget _host(TagDragOverlay overlay) {
  return ProviderScope(
    overrides: [
      tagTreeProvider.overrideWith(_FakeTagTree.new),
      currentMediaTagsProvider.overrideWith(_FakeCurrentMediaTags.new),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Stack(children: [Positioned.fill(child: overlay)]),
      ),
    ),
  );
}

void main() {
  for (final turns in [0, 1]) {
    testWidgets('媒体旋转 $turns 时浮层可正常展开并布局', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final key = GlobalKey<TagDragOverlayState>();
      await tester.pumpWidget(
        _host(TagDragOverlay(key: key, bottomInset: 96, quarterTurns: turns)),
      );
      await tester.pump();

      // 展开常驻浮层：这一步会走完整的面板/取消区/拖拽提示构建路径
      key.currentState!.openPinned();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('快速打标签'), findsOneWidget);
      expect(find.text('小猫'), findsWidgets);
    });
  }

  testWidgets('拖拽激活后命中标签行不报错（旋转 90°）', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final key = GlobalKey<TagDragOverlayState>();
    await tester.pumpWidget(
      _host(TagDragOverlay(key: key, bottomInset: 96, quarterTurns: 1)),
    );
    await tester.pump();

    // 模拟从底部"标签"按钮向上拖动：屏幕坐标由浮层自行换算到自身坐标系
    key.currentState!.startDrag(const Offset(200, 780));
    key.currentState!.updateDrag(const Offset(120, 700));
    await tester.pump();
    expect(tester.takeException(), isNull);

    key.currentState!.updateDrag(const Offset(80, 400));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await key.currentState!.endDrag(const Offset(80, 400));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
