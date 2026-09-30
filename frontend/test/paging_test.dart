// 媒体分页游标（MediaPager）的回归测试。
//
// 覆盖：页大小口径、是否还有更多（服务端总数 / 未知总数）、最后一页、空页、
// 去重追加与 offset 语义。纯逻辑，不依赖设备与网络。
import 'package:flutter_test/flutter_test.dart';
import 'package:torrid/core/constants/paging.dart';
import 'package:torrid/features/gallery/models/media_asset.dart';
import 'package:torrid/features/gallery/services/media_pagination.dart';

MediaAsset _asset(String id, {String? message}) {
  return MediaAsset(
    id: id,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    capturedAt: DateTime(2026, 1, 1),
    filePath: '$id.jpg',
    hash: 'hash-$id',
    message: message,
  );
}

List<String> _ids(MediaPager pager) => [for (final a in pager.items) a.id];

void main() {
  group('页大小', () {
    test('默认页大小取服务端同一口径的常量', () {
      expect(MediaPager().pageSize, mediaPageSize);
      expect(MediaPager.defaultPageSize, mediaPageSize);
    });

    test('可指定页大小（画廊下载批次）', () {
      expect(MediaPager(pageSize: 50).pageSize, 50);
    });
  });

  group('是否还有更多', () {
    test('按服务端总数收口, 最后一页后不再有更多', () {
      final pager = MediaPager(pageSize: 2);

      pager.add([_asset('a'), _asset('b')], total: 5);
      expect(pager.hasMore, isTrue);
      expect(pager.total, 5);

      pager.add([_asset('c'), _asset('d')], total: 5);
      expect(pager.hasMore, isTrue, reason: '已加载 4 < 总数 5');

      pager.add([_asset('e')], total: 5);
      expect(pager.hasMore, isFalse);
      expect(pager.offset, 5);
    });

    test('空页即到底（总数仍大于已加载时也不例外）', () {
      final pager = MediaPager(pageSize: 2);
      pager.add([_asset('a'), _asset('b')], total: 100);

      pager.add(const [], total: 100);

      expect(pager.hasMore, isFalse);
      expect(pager.offset, 2, reason: '空页不推进游标');
      expect(_ids(pager), ['a', 'b']);
    });

    test('服务端不给总数时按整页判断（画廊批次接口）', () {
      final pager = MediaPager(pageSize: 2);

      pager.add([_asset('a'), _asset('b')]);
      expect(pager.hasMore, isTrue, reason: '满页说明后面可能还有');

      pager.add([_asset('c')]);
      expect(pager.hasMore, isFalse, reason: '不足一页即到底');
      expect(pager.total, 3, reason: '总数未知时等于已消费条数');
    });
  });

  group('去重追加', () {
    test('同一 id 只保留一行, 重复行以新数据覆盖且保持原位置', () {
      final pager = MediaPager(pageSize: 2);

      pager.add([_asset('a'), _asset('b')], total: 3);
      pager.add([_asset('b', message: '新'), _asset('c')], total: 3);

      expect(_ids(pager), ['a', 'b', 'c']);
      expect(pager.items[1].message, '新');
      expect(pager.items.length, 3);
    });

    test('页内重复同样只保留一行, 但 offset 按服务端条数前进', () {
      final pager = MediaPager(pageSize: 2);

      pager.add([_asset('a'), _asset('a')], total: 4);

      expect(_ids(pager), ['a']);
      expect(pager.offset, 2, reason: '本地去重不能影响服务端游标');
      expect(pager.hasMore, isTrue);
    });
  });

  group('对齐本地游标', () {
    test('seek 从本地已有条数继续, 并清空上一轮结果', () {
      final pager = MediaPager(pageSize: 2);
      pager.add([_asset('a'), _asset('b')], total: 10);

      pager.seek(8);
      expect(pager.offset, 8);
      expect(pager.items, isEmpty);
      expect(pager.hasMore, isTrue);

      pager.add([_asset('i'), _asset('j')], total: 10);
      expect(_ids(pager), ['i', 'j']);
      expect(pager.hasMore, isFalse);
      expect(pager.offset, 10);
    });

    test('reset 等价于从零开始', () {
      final pager = MediaPager(pageSize: 2);
      pager.add([_asset('a'), _asset('b')], total: 10);

      pager.reset();

      expect(pager.offset, 0);
      expect(pager.items, isEmpty);
      expect(pager.hasMore, isTrue);
      expect(pager.total, 0);
    });
  });
}
