import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torrid/core/services/storage/app_database.dart';
import 'package:torrid/core/services/storage/user_data_sync.dart';
import 'package:torrid/core/utils/serialization.dart';
import 'package:torrid/features/booklet/storage/booklet_store.dart';
import 'package:torrid/features/chat/services/chat_api_service.dart';
import 'package:torrid/features/essay/models/essay.dart';
import 'package:torrid/features/essay/models/essay_draft.dart';
import 'package:torrid/features/essay/models/label.dart';
import 'package:torrid/features/essay/services/essay_draft_store.dart';
import 'package:torrid/features/essay/services/essay_store.dart';

void main() {
  final fixture =
      jsonDecode(File('../contracts/user_data.json').readAsStringSync())
          as Map<String, dynamic>;
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  for (final item in fixture['merge_cases'] as List) {
    test(item['name'] as String, () async {
      final store = EssayStore(db);
      final client = Map<String, dynamic>.from(item['client'] as Map);
      final before = jsonEncode(client);
      await store.syncData(UserDataBatch('essay', client), address: 'test');
      final server = UserDataBatch(
        'essay',
        Map<String, dynamic>.from(item['server'] as Map),
      );
      await store.syncData(server, address: 'test');

      final expected = item['expected'] as Map?;
      final labels = (await store.labels())
          .where((label) => !label.isHiddenRoot)
          .toList();
      if (expected == null) {
        expect(labels, isEmpty);
      } else {
        final actual = labels.single;
        expect(actual.id, expected['id']);
        expect(actual.name, expected['name']);
        expect(
          actual.updatedAt,
          DateTime.parse(expected['updated_at'] as String),
        );
      }
      expect(jsonEncode(client), before);

      final snapshot = jsonEncode((await store.snapshot()).data);
      await store.syncData(server, address: 'test');
      expect(jsonEncode((await store.snapshot()).data), snapshot);
    });
  }

  test('无效数据不推进游标，失败后允许重试', () async {
    final store = BookletStore(db);
    await db.saveSyncCursor('test', 'booklet', 8);
    final data = <String, dynamic>{
      'sync_version': 2,
      'cursor': 9,
      'styles': [],
      'records': [],
      'tombstones': [],
    };
    expect(
      () => UserDataBatch('booklet', {...data, 'cursor': -1}),
      throwsFormatException,
    );
    await expectLater(
      store.syncData(
        UserDataBatch('booklet', {
          ...data,
          'records': [
            {
              'id': fixture['id'],
              'style_id': fixture['id'],
              'date': '2026-03-01',
              'message': '',
              'task_completion': <String, bool>{},
              'updated_at': '2026-01-01T00:00:00Z',
            },
          ],
        }),
        address: 'test',
      ),
      throwsFormatException,
    );
    expect(await db.syncCursor('test', 'booklet'), 8);
    expect(await store.styles(), isEmpty);
    expect(await store.records(), isEmpty);
    await store.syncData(UserDataBatch('booklet', data), address: 'test');
    expect(await db.syncCursor('test', 'booklet'), 9);
    expect(await db.syncCursor('other', 'booklet'), 0);
  });

  test('随笔分离正文和标签版本，外键失败回滚本批次和游标', () async {
    final store = EssayStore(db);
    final id = fixture['id'] as String;
    const other = '90000000-0000-4000-8000-000000000002';
    const unknown = '90000000-0000-4000-8000-000000000003';
    const old = '2026-01-01T00:00:00.001Z';
    const newer = '2026-01-01T00:00:00.002Z';
    const latest = '2026-01-01T00:00:00.003Z';
    final first = {
      'id': id,
      'date': '2026-01-01T00:00:00.123456Z',
      'created_at': old,
      'updated_at': newer,
      'labels_updated_at': old,
      'word_count': 4,
      'title': '',
      'content': '新正文',
      'imgs': <String>[],
      'labels': [Label.hiddenId],
      'messages': <Object>[],
    };
    final empty = {
      'sync_version': 2,
      'labels': <Object>[],
      'essays': <Object>[],
      'tombstones': <Object>[],
    };
    await store.syncData(
      UserDataBatch('essay', {
        ...empty,
        'cursor': 1,
        'essays': [first],
      }),
      address: 'test',
    );
    expect(await store.hiddenEssayIds(), [id]);
    final update = {
      ...first,
      'content': '旧正文',
      'updated_at': old,
      'labels_updated_at': latest,
      'labels': [other],
    };
    await store.syncData(
      UserDataBatch('essay', {
        ...empty,
        'cursor': 2,
        'essays': [update],
        'labels': [
          {'id': other, 'name': '可见', 'updated_at': newer},
        ],
      }),
      address: 'test',
    );
    final merged = (await store.essay(id))!;
    expect(merged.content, '新正文');
    expect(merged.labels, [other]);
    expect(merged.updatedAt, DateTime.parse(newer));
    expect(merged.labelsUpdatedAt, DateTime.parse(latest));
    expect(merged.date.toUtc(), DateTime.parse(first['date'] as String));
    expect(await store.hiddenEssayIds(), isEmpty);
    await expectLater(
      store.syncData(
        UserDataBatch('essay', {
          ...empty,
          'cursor': 3,
          'essays': [
            {
              ...first,
              'updated_at': latest,
              'labels_updated_at': latest,
              'labels': [unknown],
            },
          ],
        }),
        address: 'test',
      ),
      throwsA(anything),
    );
    expect(await db.syncCursor('test', 'essay'), 2);
    expect((await store.essay(id))!.labels, [other]);
  });

  test('草稿保存冲突保留草稿，留言和标签各自更新时间', () async {
    final store = EssayStore(db);
    final drafts = EssayDraftStore(db);
    await store.saveLabel(name: '可见');
    final label = (await store.labels()).firstWhere(
      (label) => !label.isHiddenRoot,
    );
    final id = fixture['id'] as String;
    final first = await store.writeEssay(
      essay: Essay(
        id: id,
        date: DateTime.now(),
        wordCount: 2,
        content: '原文',
        imgs: [],
        labels: [label.id],
        messages: [],
      ),
    );
    await store.appendMessage(id, ' 留言 ');
    final commented = (await store.essay(id))!;
    expect(commented.updatedAt!.isAfter(first.updatedAt!), isTrue);
    expect(commented.labelsUpdatedAt, first.labelsUpdatedAt);
    await store.retag(id, Label.hiddenId);
    final retagged = (await store.essay(id))!;
    expect(retagged.updatedAt, commented.updatedAt);
    expect(
      retagged.labelsUpdatedAt!.isAfter(commented.labelsUpdatedAt!),
      isTrue,
    );

    final edited = first.copyWith(content: '草稿');
    await drafts.save(
      EssayDraft(essay: edited, original: first, updatedAt: DateTime.now()),
    );
    await store.writeEssay(
      essay: retagged.copyWith(content: '其他编辑'),
      original: retagged,
    );
    await drafts.save(
      EssayDraft(essay: edited, original: first, updatedAt: DateTime.now()),
    );
    await expectLater(
      store.writeEssay(essay: edited, original: first),
      throwsStateError,
    );
    expect((await drafts.forEssay(id))!.essay.content, '草稿');
    expect((await store.essay(id))!.content, '其他编辑');

    final current = (await store.essay(id))!;
    final saved = await store.writeEssay(
      essay: edited.copyWith(labels: current.labels),
      original: current,
    );
    expect(saved.messages.single.content, '留言');
    expect(await drafts.forEssay(id), isNull);
  });

  test('日历日与时刻按各自语义往返', () {
    for (final text in fixture['calendar_dates'] as List) {
      expect(dateToJson(dateFromJson(text as String)), text.substring(0, 10));
    }
    for (final text in fixture['instants'] as List) {
      expect(
        DateTime.parse(dateTimeToJson(dateTimeFromJson(text as String))),
        DateTime.parse(text),
      );
    }
  });

  test('对话信息使用服务端契约', () {
    final data =
        jsonDecode(File('../contracts/ai.json').readAsStringSync())['chat_info']
            as Map<String, dynamic>;
    final info = ChatServerInfo.fromJson(data);
    expect(info.model, data['model']);
    expect(info.candidates.single.current, isTrue);
    expect(info.candidates.single.vision, isTrue);
    expect(info.numCtx, data['num_ctx']);
    expect(info.keepAliveSeconds, data['keep_alive_seconds']);
    expect(info.ready, isTrue);
  });
}
