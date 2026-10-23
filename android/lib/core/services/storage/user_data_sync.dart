import 'dart:async';
import 'dart:convert';

import 'package:hive/hive.dart';

Box<String> get userDataSyncBox => Hive.box<String>('userDataSync');
final _uuid = RegExp(
  r'^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$',
  caseSensitive: false,
);
DateTime _version(Map<String, dynamic> row) =>
    DateTime.tryParse(row['updated_at'] as String? ?? '') ??
    DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

Future<void> _writes = Future.value();

Future<T> userDataWrite<T>(Future<T> Function() action) {
  final result = _writes.then((_) => action());
  _writes = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
  return result;
}

DateTime nextUserDataTime([DateTime? previous]) {
  final now = DateTime.now().millisecondsSinceEpoch;
  final floor = (previous?.millisecondsSinceEpoch ?? 0) + 1;
  return DateTime.fromMillisecondsSinceEpoch(
    now > floor ? now : floor,
    isUtc: true,
  );
}

List<Map<String, dynamic>> userDataTombstones(String module) => [
  for (final entry in userDataSyncBox.toMap().entries)
    if (entry.key.toString().startsWith('deleted|$module|'))
      Map<String, dynamic>.from(jsonDecode(entry.value) as Map),
];

Map<String, String> deletedUserData(
  String module,
  String collection,
  String id,
  DateTime? previous, {
  Map<String, String>? metadata,
}) {
  final current = metadata ?? userDataSyncBox.toMap().cast<String, String>();
  final key = 'deleted|$module|$collection|$id';
  final old = current[key];
  if (old != null) {
    final stamp = DateTime.parse(jsonDecode(old)['updated_at'] as String);
    if (previous == null || stamp.isAfter(previous)) previous = stamp;
  }
  return {
    ...current,
    key: jsonEncode({
      'collection': collection,
      'id': id,
      'updated_at': nextUserDataTime(previous).toIso8601String(),
    }),
  };
}

({Map<String, dynamic> data, Map<String, String> metadata}) mergeUserData(
  String module,
  Map<String, dynamic> local,
  Map<String, dynamic> incoming,
) {
  if (incoming['sync_version'] != 2) {
    throw const FormatException('服务端不支持增量合并，请先更新后端');
  }
  if (incoming['cursor'] is! int || (incoming['cursor'] as int) < 0) {
    throw const FormatException('服务端返回了无效的同步游标');
  }
  local = Map<String, dynamic>.from(jsonDecode(jsonEncode(local)) as Map);
  final metadata = userDataSyncBox.toMap().cast<String, String>();
  final collections = module == 'essay'
      ? ['labels', 'essays']
      : ['styles', 'records'];
  final deletions = <String, DateTime>{};
  for (final item in [
    ...userDataTombstones(module),
    ...((incoming['tombstones'] as List).cast<Map>()),
  ]) {
    final collection = item['collection'] as String;
    final id = item['id'] as String;
    if (!collections.contains(collection) || !_uuid.hasMatch(id)) {
      throw const FormatException('无效的删除标记');
    }
    final stamp = DateTime.parse(item['updated_at'] as String);
    final key = '$collection|$id';
    if (deletions[key]?.isAfter(stamp) ?? false) continue;
    deletions[key] = stamp;
    metadata['deleted|$module|$key'] = jsonEncode(item);
  }
  final result = <String, dynamic>{'year_summaries': <dynamic>[]};
  for (final collection in collections) {
    final rows = <String, Map<String, dynamic>>{};
    for (final remote in [false, true]) {
      final source = (remote ? incoming : local)[collection] as List;
      final seen = <String>{};
      for (final value in source) {
        final row = Map<String, dynamic>.from(value as Map);
        final id = row['id'] as String;
        if (!_uuid.hasMatch(id) || !seen.add(id)) {
          throw const FormatException('数据 ID 无效或重复');
        }
        if (remote &&
            DateTime.tryParse(row['updated_at'] as String? ?? '') == null) {
          throw const FormatException('数据缺少更新时间');
        }
        final stamp = _version(row);
        final old = rows[id];
        // 同时间保留服务端版本；本地更新必须生成新的毫秒时间戳。
        if (old == null || !_version(old).isAfter(stamp)) {
          rows[id] = row;
        }
      }
    }
    rows.removeWhere((id, row) {
      final deleted = deletions['$collection|$id'];
      return deleted != null && !_version(row).isAfter(deleted);
    });
    result[collection] = rows.values.toList();
  }
  return (data: result, metadata: metadata);
}
