// 合并后的媒体网格单元 (MediaGridCell) 回归测试。
//
// 三种布局共用同一份"文件解析 / 占位 / 角标 / 回调"逻辑, 这里覆盖:
// 占位与错误态、角标叠层与位置、点击/长按/双击回调、三种布局各自的尺寸口径。
// 用真实 [File] 作为解析结果（不引入新依赖）, 不触达 sqflite / path_provider。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torrid/features/gallery/models/media_asset.dart';
import 'package:torrid/features/gallery/widgets/browser/media_grid_cell.dart';

/// 单元大小与瀑布流列宽口径一致
const double _cell = 120;

int _seq = 0;

/// 每个单元用互不相同的路径: 单元内部的文件缓存是进程级全局的
MediaAsset _asset({
  bool hasThumb = true,
  bool video = false,
  bool deleted = false,
  String? groupId,
  String? editParams,
}) {
  _seq++;
  return MediaAsset(
    id: 'm$_seq',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    capturedAt: DateTime(2026, 1, 1),
    filePath: 'media/m$_seq.${video ? 'mp4' : 'jpg'}',
    thumbPath: hasThumb ? 'thumbs/m$_seq.jpg' : null,
    hash: 'hash-$_seq',
    isDeleted: deleted,
    groupId: groupId,
    editParams: editParams,
  );
}

/// 假文件解析: 只要给了路径就返回文件对象, 不做磁盘读写
Future<File?> _existingFile(MediaAsset asset, {required bool preview}) async {
  final path = preview ? asset.previewPath ?? asset.thumbPath : asset.thumbPath;
  return path == null ? null : File(path);
}

/// 占位容器（图标所在的那一层）
Finder get _placeholderBox => find
    .ancestor(of: find.byType(Icon), matching: find.byType(Container))
    .first;

Widget _host(
  Widget cell, {
  double width = _cell,
  double? height,
  bool looseHeight = false,
}) {
  return ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            height: looseHeight ? null : (height ?? width),
            child: cell,
          ),
        ),
      ),
    ),
  );
}

MediaGridCell _gridCell(
  MediaAsset asset, {
  required MediaGridCellLayout layout,
  bool isSelected = false,
  bool isCurrent = false,
  int? selectionIndex,
  bool isSelectionMode = false,
  bool hasTags = false,
  VoidCallback? onTap,
  VoidCallback? onLongPress,
  VoidCallback? onDoubleTap,
  Future<File?> Function(MediaAsset, {required bool preview})? resolveFile,
}) {
  return MediaGridCell(
    asset: asset,
    layout: layout,
    isSelected: isSelected,
    isCurrent: isCurrent,
    selectionIndex: selectionIndex,
    isSelectionMode: isSelectionMode,
    hasTags: hasTags,
    cellWidth: layout == MediaGridCellLayout.waterfall ? _cell : null,
    onTap: onTap ?? () {},
    onLongPress: onLongPress ?? () {},
    onDoubleTap: onDoubleTap,
    // 默认注入假解析: 单元内部只在"有路径可解析"时才会调用它
    resolveFile: resolveFile ?? _existingFile,
  );
}

void main() {
  group('图片源与占位', () {
    testWidgets('无本地缓存路径时显示占位, 不触达存储层', (tester) async {
      await tester.pumpWidget(
        _host(_gridCell(_asset(hasThumb: false), layout: MediaGridCellLayout.thumb)),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: '不应调用 path_provider');
      expect(find.byIcon(Icons.image), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('视频占位使用摄像机图标', (tester) async {
      await tester.pumpWidget(
        _host(
          _gridCell(_asset(hasThumb: false, video: true),
              layout: MediaGridCellLayout.thumb),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.videocam), findsOneWidget);
    });

    for (final layout in MediaGridCellLayout.values) {
      testWidgets('$layout: 解析到文件后换成图片（不再停留在占位）', (tester) async {
        await tester.pumpWidget(
          _host(
            _gridCell(_asset(), layout: layout),
            looseHeight: layout != MediaGridCellLayout.thumb,
          ),
        );
        await tester.pumpAndSettle();

        // 文件字节由系统决定能否解码, 这里只断言"已切到图片分支"
        expect(find.byType(Image), findsOneWidget);
      });
    }
  });

  group('尺寸口径', () {
    testWidgets('缩略图网格: 占位铺满方形单元', (tester) async {
      await tester.pumpWidget(
        _host(
          _gridCell(_asset(hasThumb: false), layout: MediaGridCellLayout.thumb),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(MediaGridCell)),
          const Size(_cell, _cell));
      expect(tester.getSize(_placeholderBox), const Size(_cell, _cell),
          reason: '占位容器应铺满单元');
    });

    testWidgets('等比预览: 占位固定为正方形（行高不跳变）', (tester) async {
      await tester.pumpWidget(
        _host(
          _gridCell(_asset(hasThumb: false),
              layout: MediaGridCellLayout.proportional),
          looseHeight: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.getSize(_placeholderBox), const Size(_cell, _cell));
    });

    testWidgets('瀑布流: 图片尺寸未知时用默认比例占位', (tester) async {
      await tester.pumpWidget(
        _host(
          _gridCell(_asset(hasThumb: false), layout: MediaGridCellLayout.waterfall),
          looseHeight: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(
          tester.getSize(_placeholderBox), const Size(_cell, _cell * 0.75));
    });
  });

  group('角标叠层', () {
    testWidgets('按资源状态显示删除/分组/标签/编辑/视频角标', (tester) async {
      await tester.pumpWidget(
        _host(
          _gridCell(
            _asset(deleted: true, groupId: 'lead', editParams: '{"type":"image"}'),
            layout: MediaGridCellLayout.thumb,
            hasTags: true,
            isCurrent: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delete), findsOneWidget);
      expect(find.byIcon(Icons.layers), findsOneWidget);
      expect(find.byIcon(Icons.label_outline), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.byIcon(Icons.visibility), findsOneWidget);
      expect(find.byIcon(Icons.play_circle_outline), findsNothing);
    });

    testWidgets('视频与分组角标同现时各就其位', (tester) async {
      await tester.pumpWidget(
        _host(
          _gridCell(
            _asset(video: true, groupId: 'lead'),
            layout: MediaGridCellLayout.thumb,
            hasTags: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
      final origin = tester.getTopLeft(find.byType(MediaGridCell));
      // 角标贴左 4px、内边距 4px: 分组角标图标在 8, 标签角标紧随其后在 28
      expect(tester.getTopLeft(find.byIcon(Icons.layers)).dx - origin.dx, 8);
      expect(tester.getTopLeft(find.byIcon(Icons.label_outline)).dx - origin.dx,
          28);
      // 视频角标贴右下
      expect(
        tester.getBottomRight(find.byIcon(Icons.play_circle_outline)).dx,
        origin.dx + _cell - 4,
      );
    });

    testWidgets('选择模式: 隐藏标签/编辑角标, 显示选中序号', (tester) async {
      await tester.pumpWidget(
        _host(
          _gridCell(
            _asset(editParams: '{"type":"image"}'),
            layout: MediaGridCellLayout.thumb,
            isSelectionMode: true,
            isSelected: true,
            selectionIndex: 3,
            hasTags: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget);
      expect(find.byIcon(Icons.label_outline), findsNothing);
      expect(find.byIcon(Icons.edit), findsNothing);
      expect(find.byIcon(Icons.visibility), findsNothing);
    });

    testWidgets('选择模式未选中: 圆点为空（无序号文本）', (tester) async {
      await tester.pumpWidget(
        _host(
          _gridCell(_asset(), layout: MediaGridCellLayout.thumb,
              isSelectionMode: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('✓'), findsNothing);
      expect(find.text('1'), findsNothing);
      expect(find.byType(Image), findsOneWidget);
    });
  });

  group('回调', () {
    testWidgets('单击触发 onTap（有双击回调时等待双击窗口）', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(_gridCell(_asset(), layout: MediaGridCellLayout.thumb,
            onTap: () => taps++, onDoubleTap: () {})),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(MediaGridCell));
      await tester.pump(const Duration(milliseconds: 400));

      expect(taps, 1);
    });

    testWidgets('长按触发 onLongPress', (tester) async {
      var longPresses = 0;
      await tester.pumpWidget(
        _host(_gridCell(_asset(), layout: MediaGridCellLayout.thumb,
            onLongPress: () => longPresses++)),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.byType(MediaGridCell));
      await tester.pumpAndSettle();

      expect(longPresses, 1);
    });

    testWidgets('双击触发 onDoubleTap 而不触发 onTap', (tester) async {
      var taps = 0;
      var doubleTaps = 0;
      await tester.pumpWidget(
        _host(
          _gridCell(_asset(), layout: MediaGridCellLayout.waterfall,
              onTap: () => taps++, onDoubleTap: () => doubleTaps++),
          looseHeight: true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(MediaGridCell));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byType(MediaGridCell));
      await tester.pumpAndSettle();

      expect(doubleTaps, 1);
      expect(taps, 0);
    });

    testWidgets('没有双击回调时, 单击立即生效', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(_gridCell(_asset(), layout: MediaGridCellLayout.thumb,
            onTap: () => taps++)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(MediaGridCell));
      await tester.pump();

      expect(taps, 1, reason: '未注册双击识别器时不等待双击窗口');
    });
  });
}
