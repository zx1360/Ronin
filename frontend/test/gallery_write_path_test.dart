// 服务端写入统一入口（GalleryWriteService）的回归测试。
//
// 覆盖：本地立即生效、写缓冲合并与退避重试、最终失败回滚、直推失败回滚、
// 重复提交的幂等性。全部用内存版 MediaWriteStore + 假推送函数验证，
// 不依赖设备、网络与 sqflite。
import 'package:flutter_test/flutter_test.dart';
import 'package:torrid/features/gallery/models/media_asset.dart';
import 'package:torrid/features/gallery/models/media_patch_intent.dart';
import 'package:torrid/features/gallery/services/gallery_write_service.dart';

MediaAsset _asset(String id, {bool isDeleted = false, String? message}) {
  return MediaAsset(
    id: id,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    capturedAt: DateTime(2026, 1, 1),
    filePath: '$id.jpg',
    hash: 'hash-$id',
    isDeleted: isDeleted,
    message: message,
  );
}

/// 内存版本地缓存：字段语义与 gallery.db 一致
class _FakeStore implements MediaWriteStore {
  final Map<String, MediaAsset> assets = {};
  final Map<String, List<String>> tagIds = {};

  @override
  Future<List<String>> readTagIds(String mediaId) async =>
      List<String>.from(tagIds[mediaId] ?? const []);

  @override
  Future<MediaAsset?> readAsset(String mediaId) async => assets[mediaId];

  @override
  Future<void> writeTagIds(String mediaId, List<String> values) async {
    tagIds[mediaId] = List<String>.from(values);
  }

  @override
  Future<void> writeTagLinks(
    List<String> mediaIds, {
    List<String> addTagIds = const [],
    List<String> removeTagIds = const [],
  }) async {
    for (final id in mediaIds) {
      final current = tagIds.putIfAbsent(id, () => []);
      current.removeWhere(removeTagIds.contains);
      for (final tagId in addTagIds) {
        if (!current.contains(tagId)) current.add(tagId);
      }
    }
  }

  @override
  Future<void> writeDeleted(List<String> mediaIds, {required bool deleted}) async {
    for (final id in mediaIds) {
      final asset = assets[id];
      if (asset != null) assets[id] = asset.copyWith(isDeleted: deleted);
    }
  }

  @override
  Future<void> writeGroupId(List<String> mediaIds, String? leadId) async {
    for (final id in mediaIds) {
      final asset = assets[id];
      if (asset != null) {
        assets[id] = asset.copyWith(
          groupId: leadId,
          clearGroupId: leadId == null,
        );
      }
    }
  }

  @override
  Future<void> writeFields(List<String> mediaIds, Map<String, Object?> values) async {
    for (final id in mediaIds) {
      var asset = assets[id];
      if (asset == null) continue;
      if (values.containsKey('message')) {
        final message = values['message'] as String?;
        asset = asset.copyWith(message: message, clearMessage: message == null);
      }
      if (values.containsKey('edit_params')) {
        final params = values['edit_params'] as String?;
        asset = asset.copyWith(editParams: params, clearEditParams: params == null);
      }
      assets[id] = asset;
    }
  }

  @override
  Future<void> writeAsset(MediaAsset asset) async => assets[asset.id] = asset;

  @override
  Future<void> writeServerRows(List<MediaAsset> rows) async {
    for (final row in rows) {
      if (assets.containsKey(row.id)) assets[row.id] = row;
    }
  }
}

/// 假服务端：记录每次推送，可按次数注入失败
class _FakeServer {
  int patchAttempts = 0;
  int tagReplaceAttempts = 0;
  int tagLinkAttempts = 0;

  /// 接下来的 N 次推送失败（用于验证重试）
  int patchFailures = 0;
  int tagLinkFailures = 0;

  final List<MediaPatchIntent> patchPayloads = [];
  final List<List<String>> tagReplacePayloads = [];
  final List<({List<String> mediaIds, List<String> add, List<String> remove})>
      tagLinkPayloads = [];

  Future<List<MediaAsset>> pushPatch(
    List<String> mediaIds,
    MediaPatchIntent intent,
  ) async {
    patchAttempts++;
    if (patchFailures-- > 0) throw Exception('离线');
    patchPayloads.add(intent);
    return [
      for (final id in mediaIds)
        _asset(id).copyWith(
          isDeleted: intent.isDeleted,
          message: intent.message,
        ),
    ];
  }

  Future<List<String>> pushTags(String mediaId, List<String> tagIds) async {
    tagReplaceAttempts++;
    tagReplacePayloads.add(tagIds);
    return tagIds;
  }

  Future<int> pushTagLinks(
    List<String> mediaIds, {
    List<String> addTagIds = const [],
    List<String> removeTagIds = const [],
  }) async {
    tagLinkAttempts++;
    if (tagLinkFailures-- > 0) throw Exception('离线');
    tagLinkPayloads.add(
      (mediaIds: mediaIds, add: addTagIds, remove: removeTagIds),
    );
    return mediaIds.length;
  }
}

typedef _Harness = ({
  GalleryWriteService service,
  _FakeStore store,
  _FakeServer server,
  List<String> reverted,
  List<String> errors,
});

_Harness _harness({int directAttempts = 2}) {
  final store = _FakeStore();
  final server = _FakeServer();
  final reverted = <String>[];
  final errors = <String>[];
  final service = GalleryWriteService(
    store: store,
    pushTags: server.pushTags,
    pushPatch: server.pushPatch,
    pushTagLinks: server.pushTagLinks,
    onReverted: () => reverted.add('reverted'),
    onError: errors.add,
    debounce: const Duration(milliseconds: 2),
    retryDelays: const [Duration(milliseconds: 2)],
    directAttempts: directAttempts,
  );
  return (
    service: service,
    store: store,
    server: server,
    reverted: reverted,
    errors: errors,
  );
}

/// 等写缓冲的 debounce 与退避重试跑完
Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 120));

void main() {
  group('本地立即生效', () {
    test('setTags 先落本地, 再在后台合并推送', () async {
      final h = _harness();

      await h.service.setTags('m1', ['t1', 't2']);

      expect(h.store.tagIds['m1'], ['t1', 't2'], reason: '不等服务端即生效');
      expect(h.server.tagReplaceAttempts, 0, reason: '推送走后台');

      await _settle();
      expect(h.server.tagReplaceAttempts, 1);
      expect(h.server.tagReplacePayloads.single, ['t1', 't2']);
    });

    test('空的标注意图与空 id 列表都不产生推送', () async {
      final h = _harness();

      await h.service.patchOne('m1', const MediaPatchIntent());
      await h.service.patchMany([], const MediaPatchIntent(isDeleted: true));

      await _settle();
      expect(h.server.patchAttempts, 0);
    });
  });

  group('失败回滚', () {
    test('写缓冲重试仍失败时, 本地回到写前状态并提示', () async {
      final h = _harness();
      h.store.assets['m1'] = _asset('m1', message: '旧备注');
      h.server.patchFailures = 99;

      await h.service.patchOne('m1', const MediaPatchIntent(message: '新备注'));
      expect(h.store.assets['m1']!.message, '新备注', reason: '本地先改');

      await _settle();

      expect(h.server.patchAttempts, 2, reason: '1 次首发 + 1 次退避重试');
      expect(h.store.assets['m1']!.message, '旧备注', reason: '最终失败必须回滚');
      expect(h.reverted, hasLength(1));
      expect(h.errors, hasLength(1));
    });

    test('直推失败时整批回滚并把异常抛给调用方', () async {
      final h = _harness();
      h.store.assets['m1'] = _asset('m1');
      h.store.assets['m2'] = _asset('m2');
      h.server.patchFailures = 99;

      await expectLater(
        h.service.patchMany(['m1', 'm2'], const MediaPatchIntent(isDeleted: true)),
        throwsA(isA<Exception>()),
      );

      expect(h.server.patchAttempts, 2, reason: 'directAttempts=2 → 重试 1 次后收口');
      expect(h.store.assets['m1']!.isDeleted, isFalse);
      expect(h.store.assets['m2']!.isDeleted, isFalse);
      expect(h.reverted, hasLength(1));
    });

    test('直推重试后成功则不回滚, 并以服务端返回覆盖本地', () async {
      final h = _harness();
      h.store.assets['m1'] = _asset('m1');
      h.server.patchFailures = 1;

      await h.service.patchMany(['m1'], const MediaPatchIntent(message: '备注'));

      expect(h.server.patchAttempts, 2);
      expect(h.store.assets['m1']!.message, '备注');
      expect(h.store.assets['m1']!.isDeleted, isFalse, reason: '旧行被整行覆盖');
      expect(h.reverted, isEmpty);
    });

    test('批次处理游标只写服务端, 不动本地', () async {
      final h = _harness();
      h.store.assets['m1'] = _asset('m1');

      await h.service.pushServerOnly(
        ['m1'],
        const MediaPatchIntent(markProcessed: true),
      );

      expect(h.server.patchPayloads.single.markProcessed, isTrue);
      expect(h.store.assets['m1']!.syncCount, 0);
    });
  });

  group('幂等与合并', () {
    test('同一媒体的连续标签写入合并为一次推送, 取最后一次', () async {
      final h = _harness();

      await h.service.setTags('m1', ['a']);
      await h.service.setTags('m1', ['a', 'b']);
      await h.service.setTags('m1', ['c']);

      await _settle();

      expect(h.server.tagReplaceAttempts, 1, reason: 'debounce 窗口内合并');
      expect(h.server.tagReplacePayloads.single, ['c']);
      expect(h.store.tagIds['m1'], ['c']);
    });

    test('同一媒体的连续标注合并后保留各字段', () async {
      final h = _harness();
      h.store.assets['m1'] = _asset('m1');

      await h.service.patchOne('m1', const MediaPatchIntent(isDeleted: true));
      await h.service.patchOne('m1', const MediaPatchIntent(message: '备注'));

      await _settle();

      expect(h.server.patchAttempts, 1);
      final intent = h.server.patchPayloads.single;
      expect(intent.isDeleted, isTrue);
      expect(intent.message, '备注');
    });

    test('重复提交同一批标签不产生重复关联', () async {
      final h = _harness();

      await h.service.addTagLinks(['m1'], ['t1']);
      await h.service.addTagLinks(['m1'], ['t1']);
      expect(h.store.tagIds['m1'], ['t1'], reason: '加标签幂等');

      await h.service.removeTagLinks(['m1'], ['t1']);
      await h.service.removeTagLinks(['m1'], ['t1']);
      expect(h.store.tagIds['m1'], isEmpty, reason: '移除标签幂等');

      expect(h.server.tagLinkAttempts, 4);
      expect(
        h.server.tagLinkPayloads.map((e) => e.add).toList(),
        [
          ['t1'],
          ['t1'],
          <String>[],
          <String>[],
        ],
      );
    });

    test('失败重试使用同一份请求载荷, 不累加本地写入', () async {
      final h = _harness();
      h.server.tagLinkFailures = 1;

      await h.service.addTagLinks(['m1'], ['t1']);

      expect(h.server.tagLinkAttempts, 2);
      expect(h.store.tagIds['m1'], ['t1'], reason: '重试不产生重复行');
      expect(h.reverted, isEmpty);
    });
  });
}
