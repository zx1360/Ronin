// 用户数据"逐行合并 + 墓碑"同步的回归测试。
//
// 合并规则与服务端 `POST /API/user-data/backup/:module` 一致，且刻意与存储无关：
// 这里全部用纯函数 + 真实模型（Essay / Record）验证，不依赖 Hive。
//
// 覆盖：更新更晚才覆盖、更旧忽略、等值忽略、墓碑删本地、墓碑被复活、
// 本地缺失则插入、服务端没下发的行不删本地、打卡记录按 (style_id, date) 合并、
// 载荷非法时在写库前抛出、上传载荷包含墓碑与时间戳。
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:torrid/core/api/user_data_sync.dart';
import 'package:torrid/features/booklet/models/record.dart';
import 'package:torrid/features/essay/models/essay.dart';

Essay _essay({
  String id = 'e1',
  String content = '内容',
  DateTime? date,
  DateTime? createdAt,
  DateTime? updatedAt,
  DateTime? deletedAt,
}) {
  return Essay(
    id: id,
    date: date ?? DateTime(2026, 1, 1, 10),
    wordCount: content.length,
    content: content,
    imgs: const [],
    labels: const [],
    messages: const [],
    createdAt: createdAt,
    updatedAt: updatedAt,
    deletedAt: deletedAt,
  );
}

Record _record({
  required String id,
  String styleId = 's1',
  DateTime? date,
  String message = '',
  DateTime? updatedAt,
  DateTime? deletedAt,
}) {
  return Record(
    id: id,
    styleId: styleId,
    date: date ?? DateTime(2026, 1, 5),
    message: message,
    taskCompletion: const {'t1': true},
    updatedAt: updatedAt,
    deletedAt: deletedAt,
  );
}

/// 与服务端下发数组严格同形的单行 JSON（含同步元数据）。
Map<String, dynamic> _essayJson({
  required String id,
  required String content,
  String? updatedAt,
  String? deletedAt,
  String? createdAt,
}) {
  return {
    'id': id,
    'date': '2026-01-01T10:00:00.000Z',
    'word_count': content.length,
    'content': content,
    'imgs': const <String>[],
    'labels': const <String>[],
    'messages': const <Map<String, dynamic>>[],
    'mood': null,
    'created_at': createdAt,
    'updated_at': updatedAt,
    'deleted_at': deletedAt,
  };
}

/// 复刻 `EssayService.syncData` 的次序：先整体解析校验、再算计划、最后才落地。
Map<String, Essay> _applyEssayPayload(
  Map<String, Essay> local,
  Map<String, dynamic> payload,
) {
  final incoming = parseSyncRows<Essay>(
    payload['essays'],
    Essay.fromJson,
    field: 'essays',
  );
  final plan = planSyncMerge<Essay>(local: local.values, incoming: incoming);
  return applySyncMergePlan<Essay>(local, plan);
}

void main() {
  group('逐行合并', () {
    test('服务端更新更晚时覆盖本地', () {
      final local = _essay(
        id: 'e1',
        content: '本地旧内容',
        updatedAt: DateTime(2026, 1, 1, 8),
      );
      final incoming = _essay(
        id: 'e1',
        content: '服务端新内容',
        updatedAt: DateTime(2026, 1, 1, 9),
      );

      final plan = planSyncMerge<Essay>(local: [local], incoming: [incoming]);

      expect(plan.applied, 1);
      expect(plan.skipped, 0);
      final merged = applySyncMergePlan<Essay>({'e1': local}, plan);
      expect(merged['e1']!.content, '服务端新内容');
    });

    test('服务端更新更旧时忽略（不得回退本地较新的编辑）', () {
      final local = _essay(
        id: 'e1',
        content: '本地新内容',
        updatedAt: DateTime(2026, 1, 1, 9),
      );
      final incoming = _essay(
        id: 'e1',
        content: '服务端旧内容',
        updatedAt: DateTime(2026, 1, 1, 8),
      );

      final plan = planSyncMerge<Essay>(local: [local], incoming: [incoming]);

      expect(plan.applied, 0);
      expect(plan.skipped, 1);
      expect(plan.upserts, isEmpty);
      expect(applySyncMergePlan<Essay>({'e1': local}, plan)['e1']!.content,
          '本地新内容');
    });

    test('时间戳相等视为幂等空操作', () {
      final stamp = DateTime(2026, 1, 1, 9);
      final local = _essay(id: 'e1', content: '本地', updatedAt: stamp);
      final incoming = _essay(id: 'e1', content: '服务端', updatedAt: stamp);

      final plan = planSyncMerge<Essay>(local: [local], incoming: [incoming]);

      expect(plan.applied, 0);
      expect(plan.skipped, 1);
      expect(applySyncMergePlan<Essay>({'e1': local}, plan)['e1']!.content, '本地');
    });

    test('本地缺失的行插入（含服务端已删的墓碑）', () {
      final live = _essay(id: 'e1', updatedAt: DateTime(2026, 1, 1, 9));
      final tomb = _essay(
        id: 'e9',
        updatedAt: DateTime(2026, 1, 1, 9),
        deletedAt: DateTime(2026, 1, 1, 9),
      );

      final plan = planSyncMerge<Essay>(local: const [], incoming: [live, tomb]);

      expect(plan.applied, 2);
      expect(plan.upserts['e1']!.isTombstone, isFalse);
      expect(plan.upserts['e9']!.isTombstone, isTrue);
    });

    test('服务端没有下发的本地行保持不动', () {
      final kept = _essay(
        id: 'e2',
        content: '本地独有',
        updatedAt: DateTime(2026, 1, 1, 9),
      );
      final local = {'e1': _essay(id: 'e1'), 'e2': kept};
      final incoming = _essay(
        id: 'e1',
        content: '服务端',
        updatedAt: DateTime(2026, 2, 1),
      );

      final plan = planSyncMerge<Essay>(local: local.values, incoming: [incoming]);
      final merged = applySyncMergePlan<Essay>(local, plan);

      expect(merged.keys.toSet(), {'e1', 'e2'});
      expect(merged['e2']!.content, '本地独有');
    });
  });

  group('墓碑', () {
    test('服务端墓碑覆盖本地活行后，本地不再可见', () {
      final local = _essay(
        id: 'e1',
        content: '要删掉的',
        updatedAt: DateTime(2026, 1, 1, 8),
      );
      final tomb = _essay(
        id: 'e1',
        content: '要删掉的',
        updatedAt: DateTime(2026, 1, 1, 9),
        deletedAt: DateTime(2026, 1, 1, 9),
      );

      final plan = planSyncMerge<Essay>(local: [local], incoming: [tomb]);
      final merged = applySyncMergePlan<Essay>({'e1': local}, plan);

      expect(plan.applied, 1);
      // 墓碑行留在 Box 里（删除动作需要继续向上游传播），但 UI/统计只看活行
      expect(liveSyncRows(merged.values), isEmpty);
    });

    test('本地墓碑被更晚的活行复活（服务端删过又改回来）', () {
      final local = _essay(
        id: 'e1',
        content: '已删',
        updatedAt: DateTime(2026, 1, 1, 9),
        deletedAt: DateTime(2026, 1, 1, 9),
      );
      final resurrected = _essay(
        id: 'e1',
        content: '复活',
        updatedAt: DateTime(2026, 1, 2),
      );

      final plan = planSyncMerge<Essay>(local: [local], incoming: [resurrected]);
      final merged = applySyncMergePlan<Essay>({'e1': local}, plan);

      expect(plan.applied, 1);
      expect(liveSyncRows(merged.values).length, 1);
      expect(merged['e1']!.content, '复活');
    });

    test('本地墓碑不会被服务端更旧的活行复活', () {
      final local = _essay(
        id: 'e1',
        updatedAt: DateTime(2026, 1, 5),
        deletedAt: DateTime(2026, 1, 5),
      );
      final stale = _essay(id: 'e1', updatedAt: DateTime(2026, 1, 1));

      final plan = planSyncMerge<Essay>(local: [local], incoming: [stale]);

      expect(plan.applied, 0);
      expect(plan.skipped, 1);
    });
  });

  group('打卡记录（业务键 style_id + date）', () {
    test('同一业务键换 id 时覆盖并清掉旧存储键', () {
      final local = _record(
        id: 'old',
        message: '旧',
        updatedAt: DateTime(2026, 1, 5, 8),
      );
      final incoming = _record(
        id: 'new',
        message: '新',
        updatedAt: DateTime(2026, 1, 5, 9),
      );

      final plan = planSyncMerge<Record>(local: [local], incoming: [incoming]);
      final merged = applySyncMergePlan<Record>({'old': local}, plan);

      expect(plan.applied, 1);
      expect(plan.removals, ['old']);
      expect(merged.keys.toList(), ['new']);
      expect(merged['new']!.message, '新');
    });

    test('时间戳相同但 id 不同（服务端采纳了另一端的 id）时对齐本地键', () {
      final stamp = DateTime(2026, 1, 5, 9);
      final local = _record(id: 'old', updatedAt: stamp);
      final incoming = _record(id: 'new', updatedAt: stamp);

      final plan = planSyncMerge<Record>(local: [local], incoming: [incoming]);

      expect(plan.applied, 1);
      expect(plan.skipped, 0);
      expect(plan.removals, ['old']);
    });

    test('不同日期的记录互不影响', () {
      final local = _record(
        id: 'a',
        date: DateTime(2026, 1, 5),
        updatedAt: DateTime(2026, 1, 5, 8),
      );
      final incoming = _record(
        id: 'b',
        date: DateTime(2026, 1, 6),
        updatedAt: DateTime(2026, 1, 6, 8),
      );

      final plan = planSyncMerge<Record>(local: [local], incoming: [incoming]);

      expect(plan.applied, 1);
      expect(plan.removals, isEmpty);
    });
  });

  group('上传载荷', () {
    test('包含墓碑行与 created_at/updated_at/deleted_at', () {
      final live = _essay(
        id: 'e1',
        content: '活着',
        createdAt: DateTime(2026, 1, 1, 1),
        updatedAt: DateTime(2026, 1, 2, 1),
      );
      final tomb = _essay(
        id: 'e2',
        content: '删了',
        updatedAt: DateTime(2026, 1, 3, 1),
        deletedAt: DateTime(2026, 1, 3, 1),
      );

      final packed = packUserData({
        'essays': [live.toJson(), tomb.toJson()],
      });
      final decoded =
          jsonDecode(packed['jsonData'] as String) as Map<String, dynamic>;
      final rows = (decoded['essays'] as List).cast<Map<String, dynamic>>();

      expect(rows.length, 2, reason: '墓碑必须一起上传，删除才能传播');
      final deleted = rows.firstWhere((row) => row['id'] == 'e2');
      expect(deleted['deleted_at'], isNotNull);
      expect(deleted['updated_at'], isNotNull);
      final kept = rows.firstWhere((row) => row['id'] == 'e1');
      expect(kept['deleted_at'], isNull);
      expect(kept['created_at'], isNotNull);
    });
  });

  group('载荷校验', () {
    test('非法行在写库前抛出，既有本地数据不被破坏', () {
      final local = {'e1': _essay(id: 'e1', content: '旧', updatedAt: DateTime(2026, 1, 1))};

      expect(
        () => _applyEssayPayload(local, {
          'essays': [
            _essayJson(
              id: 'e2',
              content: '合法',
              updatedAt: '2026-01-02T00:00:00.000Z',
            ),
            // 非法：id 不是字符串（合法行排在前面，用于验证"先全部解析"）
            {'id': 42},
          ],
        }),
        throwsA(anything),
      );

      expect(local.keys.toList(), ['e1']);
      expect(local['e1']!.content, '旧');
    });

    test('缺少集合键时抛出（不再静默当空表处理）', () {
      expect(
        () => parseSyncRows<Essay>(null, Essay.fromJson, field: 'essays'),
        throwsA(isA<FormatException>()),
      );
    });

    test('服务端时间戳按 UTC 解析、按 UTC 序列化，往返不漂移', () {
      final row = _essayJson(
        id: 'e1',
        content: 'x',
        updatedAt: '2026-01-02T03:04:05.000Z',
      );
      final essay = Essay.fromJson(row);
      expect(essay.updatedAt!.toUtc(), DateTime.utc(2026, 1, 2, 3, 4, 5));
      expect(essay.toJson()['updated_at'], '2026-01-02T03:04:05.000Z');
    });
  });
}
