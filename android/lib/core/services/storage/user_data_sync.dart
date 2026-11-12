import 'package:drift/drift.dart';
import 'package:torrid/core/services/storage/app_database.dart';

const essayCollections = ['labels', 'essays'];
const bookletCollections = ['styles', 'records'];
final _uuid = RegExp(
  r'^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$',
  caseSensitive: false,
);

DateTime nextUserDataTime([DateTime? previous]) {
  final now = DateTime.now().millisecondsSinceEpoch;
  final floor = (previous?.millisecondsSinceEpoch ?? 0) + 1;
  return DateTime.fromMillisecondsSinceEpoch(
    now > floor ? now : floor,
    isUtc: true,
  );
}

DateTime _readVersion(Object? value) {
  final time = value is String ? DateTime.tryParse(value) : null;
  if (time == null) throw const FormatException('数据缺少有效的更新时间');
  return time.toUtc();
}

class UserDataBatch {
  UserDataBatch(this.module, Map<String, dynamic> data)
    : cursor = _readCursor(data) {
    final collections = module == 'essay'
        ? essayCollections
        : bookletCollections;
    for (final collection in collections) {
      final values = data[collection];
      if (values is! List) throw FormatException('缺少数据集合 $collection');
      final entries = <String, Map<String, dynamic>>{};
      for (final raw in values) {
        if (raw is! Map<String, dynamic>) {
          throw const FormatException('无效的同步记录');
        }
        final id = raw['id'];
        if (id is! String || !_uuid.hasMatch(id) || entries.containsKey(id)) {
          throw const FormatException('数据 ID 无效或重复');
        }
        _readVersion(raw['updated_at']);
        if (collection == 'essays' && raw['labels_updated_at'] != null) {
          _readVersion(raw['labels_updated_at']);
        }
        entries[id] = raw;
      }
      _rows[collection] = entries;
    }
    final deleted = data['tombstones'];
    if (deleted is! List) throw const FormatException('缺少删除标记列表');
    for (final raw in deleted) {
      if (raw is! Map || !collections.contains(raw['collection'])) {
        throw const FormatException('无效的删除标记');
      }
      final id = raw['id'];
      if (id is! String || !_uuid.hasMatch(id)) {
        throw const FormatException('无效的删除标记 ID');
      }
      final stamps = _deletions.putIfAbsent(
        raw['collection'] as String,
        () => {},
      );
      final stamp = _readVersion(raw['updated_at']);
      if (stamps[id]?.isAfter(stamp) != true) stamps[id] = stamp;
    }
  }

  final String module;
  final int cursor;
  final _rows = <String, Map<String, Map<String, dynamic>>>{};
  final _deletions = <String, Map<String, DateTime>>{};

  Map<String, Map<String, dynamic>> rows(String collection) =>
      _rows[collection]!;

  Set<String> affectedIds(String collection) => {
    ...rows(collection).keys,
    ...?_deletions[collection]?.keys,
  };

  static int _readCursor(Map<String, dynamic> data) {
    if (data['sync_version'] != 2) {
      throw const FormatException('服务端不支持增量合并，请先更新后端');
    }
    final cursor = data['cursor'];
    if (cursor is! int || cursor < 0) {
      throw const FormatException('服务端返回了无效的同步游标');
    }
    return cursor;
  }
}

extension UserDataSyncState on AppDatabase {
  Future<int> syncCursor(String address, String module) async {
    final row =
        await (select(syncCursors)..where(
              (row) => row.address.equals(address) & row.module.equals(module),
            ))
            .getSingleOrNull();
    return row?.revision ?? 0;
  }

  Future<void> saveSyncCursor(String address, String module, int revision) =>
      into(syncCursors).insertOnConflictUpdate(
        SyncCursor(address: address, module: module, revision: revision),
      );

  Future<List<Map<String, String>>> tombstones(String module) async => [
    for (final row in await (select(
      syncDeletions,
    )..where((row) => row.module.equals(module))).get())
      {
        'collection': row.collection,
        'id': row.id,
        'updated_at': row.updatedAt.toUtc().toIso8601String(),
      },
  ];

  Future<DateTime?> deletedAt(
    String module,
    String collection,
    String id,
  ) async {
    final row =
        await (select(syncDeletions)..where(
              (row) =>
                  row.module.equals(module) &
                  row.collection.equals(collection) &
                  row.id.equals(id),
            ))
            .getSingleOrNull();
    return row?.updatedAt;
  }

  Future<void> deleteVersion(
    String module,
    String collection,
    String id,
    DateTime? previous,
  ) async {
    final deleted = await deletedAt(module, collection, id);
    final latest = previous == null || (deleted?.isAfter(previous) ?? false)
        ? deleted
        : previous;
    await into(syncDeletions).insertOnConflictUpdate(
      SyncDeletion(
        module: module,
        collection: collection,
        id: id,
        updatedAt: nextUserDataTime(latest),
      ),
    );
  }

  Future<Map<String, DateTime>> deletionVersions(
    UserDataBatch sync,
    String collection, {
    bool save = false,
  }) async {
    final ids = sync.affectedIds(collection);
    if (ids.isEmpty) return {};
    final versions = {
      for (final row
          in await (select(syncDeletions)..where(
                (row) =>
                    row.module.equals(sync.module) &
                    row.collection.equals(collection) &
                    row.id.isIn(ids),
              ))
              .get())
        row.id: row.updatedAt,
    };
    final newer = <SyncDeletion>[];
    for (final entry
        in (sync._deletions[collection] ?? const <String, DateTime>{})
            .entries) {
      if (versions[entry.key]?.compareTo(entry.value) case final int order
          when order >= 0) {
        continue;
      }
      versions[entry.key] = entry.value;
      newer.add(
        SyncDeletion(
          module: sync.module,
          collection: collection,
          id: entry.key,
          updatedAt: entry.value,
        ),
      );
    }
    if (save && newer.isNotEmpty) {
      await batch((b) => b.insertAllOnConflictUpdate(syncDeletions, newer));
    }
    return versions;
  }
}

bool isDeleted(DateTime version, DateTime? deletion) =>
    deletion != null && !version.isAfter(deletion);

/// 图片预取使用同一行版本和删除判定，只读取本地图片引用。
Set<String> syncAttachmentPaths(
  Map<String, ({DateTime updatedAt, Iterable<String> paths})> local,
  Map<String, Map<String, dynamic>> remote,
  Map<String, DateTime> deletions,
  Iterable<String> Function(Map<String, dynamic>) readPaths,
) => {
  for (final entry in local.entries)
    if (!isDeleted(entry.value.updatedAt, deletions[entry.key]) &&
        (!remote.containsKey(entry.key) ||
            entry.value.updatedAt.isAfter(
              _readVersion(remote[entry.key]!['updated_at']),
            )))
      ...entry.value.paths,
  for (final entry in remote.entries)
    if (!isDeleted(
          _readVersion(entry.value['updated_at']),
          deletions[entry.key],
        ) &&
        local[entry.key]?.updatedAt.isAfter(
              _readVersion(entry.value['updated_at']),
            ) !=
            true)
      ...readPaths(entry.value),
};
