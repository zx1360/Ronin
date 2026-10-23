import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:torrid/core/services/storage/user_data_sync.dart';
import 'package:torrid/core/utils/serialization.dart';
import 'package:torrid/features/booklet/models/record.dart';
import 'package:torrid/features/booklet/models/style.dart';
import 'package:torrid/features/booklet/providers/data_source_provider.dart';
import 'package:torrid/features/booklet/providers/routine_service_provider.dart';
import 'package:torrid/features/chat/services/chat_api_service.dart';

void main() {
  final fixture =
      jsonDecode(File('../contracts/user_data.json').readAsStringSync())
          as Map<String, dynamic>;
  late Directory directory;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('ronin-contract-');
    Hive.init(directory.path);
    await Hive.openBox<String>('userDataSync');
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });
  setUp(() => userDataSyncBox.clear());

  for (final item in fixture['merge_cases'] as List) {
    test(item['name'] as String, () async {
      final client = Map<String, dynamic>.from(item['client'] as Map);
      for (final deletion in client['tombstones'] as List) {
        await userDataSyncBox.put(
          'deleted|essay|${deletion['collection']}|${deletion['id']}',
          jsonEncode(deletion),
        );
      }
      final before = jsonEncode(client);
      final result = mergeUserData(
        'essay',
        client,
        Map<String, dynamic>.from(item['server'] as Map),
      );
      expect(
        result.data['labels'],
        item['expected'] == null ? [] : [item['expected']],
      );
      expect(jsonEncode(client), before);
      final repeated = mergeUserData(
        'essay',
        result.data,
        Map<String, dynamic>.from(item['server'] as Map),
      );
      expect(repeated.data, result.data);
    });
  }
  test('无效数据不推进游标，失败后允许重试', () async {
    final styles = await Hive.openBox<Style>('contractStyles');
    final records = await Hive.openBox<Record>('contractRecords');
    final container = ProviderContainer(
      overrides: [
        styleBoxProvider.overrideWith((ref) => styles),
        recordBoxProvider.overrideWith((ref) => records),
      ],
    );
    addTearDown(container.dispose);
    await userDataSyncBox.put('cursor|test|booklet', '8');
    final data = <String, dynamic>{
      'sync_version': 2,
      'cursor': 9,
      'styles': [],
      'records': [],
      'tombstones': [],
    };
    final service = container.read(routineServiceProvider.notifier);
    await expectLater(
      service.syncData({
        ...data,
        'cursor': -1,
      }, cursorKey: 'cursor|test|booklet'),
      throwsFormatException,
    );
    await expectLater(
      service.syncData({
        ...data,
        'records': [
          {
            'id': fixture['id'],
            'style_id': fixture['id'],
            'date': '2026-03-01',
            'message': '',
            'task_completion': {},
            'updated_at': '2026-01-01T00:00:00Z',
          },
        ],
      }, cursorKey: 'cursor|test|booklet'),
      throwsFormatException,
    );
    expect(userDataSyncBox.get('cursor|test|booklet'), '8');
    expect(styles.values, isEmpty);
    expect(records.values, isEmpty);
    await service.syncData(data, cursorKey: 'cursor|test|booklet');
    expect(userDataSyncBox.get('cursor|test|booklet'), '9');
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
