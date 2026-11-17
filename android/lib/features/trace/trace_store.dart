import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/core/services/storage/app_database.dart';
import 'package:uuid/uuid.dart';

import 'trace_clock.dart';
import 'trace_data.dart';

final traceStoreProvider = Provider(
  (ref) => TraceStore(ref.watch(appDatabaseProvider)),
);
final traceDataProvider = StreamProvider.autoDispose(
  (ref) => ref.watch(traceStoreProvider).watch(),
);

class TraceStore {
  TraceStore(this.db, {this.readClock = TraceClock.read});

  final AppDatabase db;
  final Future<TraceClock> Function() readClock;
  static const _uuid = Uuid();

  Stream<TraceData> watch() => db
      .customSelect(
        'SELECT 1',
        readsFrom: {
          db.traceScenes,
          db.traceItems,
          db.traceTags,
          db.traceSessions,
        },
      )
      .watch()
      .asyncMap((_) => db.transaction(() => _read(includeDeleted: false)));

  Future<TraceData> _read({required bool includeDeleted}) async => TraceData(
    await (db.select(
      db.traceScenes,
    )..orderBy([(s) => OrderingTerm.asc(s.id)])).get(),
    await (db.select(
      db.traceItems,
    )..orderBy([(i) => OrderingTerm.asc(i.name)])).get(),
    await (db.select(
      db.traceTags,
    )..orderBy([(t) => OrderingTerm.asc(t.name)])).get(),
    await (db.select(db.traceSessions)
          ..where(
            (s) =>
                includeDeleted ? const Constant(true) : s.deleted.equals(false),
          )
          ..orderBy([
            (s) => OrderingTerm.desc(s.startedMs),
            (s) => OrderingTerm.asc(s.id),
          ]))
        .get(),
  );

  SimpleSelectStatement<TraceSessions, TraceSession> _running() =>
      db.select(db.traceSessions)
        ..where((s) => s.endedMs.isNull() & s.deleted.equals(false));

  Future<List<TraceSession>> running({bool importedOnly = false}) =>
      (_running()
            ..where(
              (s) => importedOnly
                  ? s.anchorDurationMs.isNull()
                  : const Constant(true),
            )
            ..orderBy([(s) => OrderingTerm.asc(s.startedMs)]))
          .get();

  Future<String> sceneName(String id) async => (await (db.select(
    db.traceScenes,
  )..where((s) => s.id.equals(id))).getSingle()).name;

  Future<TraceScene> saveScene({
    TraceScene? scene,
    required String name,
    required int color,
    bool? archived,
  }) {
    final table = db.traceScenes;
    final row = TraceScene(
      id: scene?.id ?? _uuid.v4(),
      name: _name(name),
      color: color,
      archived: archived ?? scene?.archived ?? false,
      version: _nextVersion(scene?.version),
    );
    Future<TraceScene> write() => _writeCatalog(
      table,
      row,
      scene == null
          ? null
          : table.id.equals(scene.id) & table.version.equals(scene.version),
    );
    if (archived != true) return write();
    return db.transaction(() async {
      if (await (_running()
                ..where((s) => s.sceneId.equals(row.id))
                ..limit(1))
              .getSingleOrNull() !=
          null) {
        throw StateError('请先结束这个场景的计时');
      }
      return write();
    });
  }

  Future<TraceItem> saveItem(
    String sceneId,
    String name, {
    TraceItem? item,
    bool? archived,
  }) {
    final table = db.traceItems;
    final row = TraceItem(
      id: item?.id ?? _uuid.v4(),
      sceneId: item?.sceneId ?? sceneId,
      name: _name(name),
      archived: archived ?? item?.archived ?? false,
      version: _nextVersion(item?.version),
    );
    return _writeCatalog(
      table,
      row,
      item == null
          ? null
          : table.id.equals(item.id) & table.version.equals(item.version),
    );
  }

  Future<TraceTag> saveTag(String name, {TraceTag? tag, bool? archived}) {
    final table = db.traceTags;
    final row = TraceTag(
      id: tag?.id ?? _uuid.v4(),
      name: _name(name),
      archived: archived ?? tag?.archived ?? false,
      version: _nextVersion(tag?.version),
    );
    return _writeCatalog(
      table,
      row,
      tag == null
          ? null
          : table.id.equals(tag.id) & table.version.equals(tag.version),
    );
  }

  String _name(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw StateError('请输入名称');
    return trimmed;
  }

  Future<T> _writeCatalog<T extends Insertable<T>>(
    TableInfo<Table, T> table,
    T row,
    Expression<bool>? match,
  ) async {
    if (match == null) {
      await db.into(table).insert(row);
    } else if (await (db.update(table)..where((_) => match)).write(row) == 0) {
      throw StateError('分类已更新，请重新打开');
    }
    return row;
  }

  Future<TraceSession> start(
    String sceneId, {
    TraceDetails details = emptyTraceDetails,
  }) async {
    final clock = await readClock();
    return db.transaction(() async {
      final available =
          await (db.select(db.traceScenes)
                ..where((s) => s.id.equals(sceneId) & s.archived.equals(false)))
              .getSingleOrNull();
      if (available == null) throw StateError('场景已归档');
      if (await (_running()
                ..where((s) => s.sceneId.equals(sceneId))
                ..limit(1))
              .getSingleOrNull() !=
          null) {
        throw StateError('这个场景已经在计时');
      }
      await _checkDetails(sceneId, details);
      return db
          .into(db.traceSessions)
          .insertReturning(
            TraceSessionsCompanion.insert(
              id: _uuid.v4(),
              sceneId: sceneId,
              startedMs: clock.wallMs,
              version: _nextVersion(null),
              itemId: Value(details.itemId),
              tagIdsJson: Value(_encodeTags(details.tagIds)),
              note: Value(details.note.trim()),
              bootKey: Value(clock.bootKey),
              anchorElapsedMs: Value(clock.elapsedMs),
              anchorDurationMs: const Value(0),
              anchorWallMs: Value(clock.wallMs),
            ),
          );
    });
  }

  Future<TraceSession> resume(TraceSession session, {int? durationMs}) async {
    final clock = await readClock();
    return _updateSession(
      session,
      (current) => current.copyWith(
        bootKey: Value(clock.bootKey),
        anchorElapsedMs: Value(clock.elapsedMs),
        anchorDurationMs: Value(durationMs ?? clock.durationMs(current)),
        anchorWallMs: Value(clock.wallMs),
      ),
      runningOnly: true,
    );
  }

  Future<TraceSession> stop(TraceSession session) async {
    final clock = await readClock();
    return _updateSession(
      session,
      (current) => _withDuration(current, clock.durationMs(current)),
      runningOnly: true,
    );
  }

  Future<TraceSession> finish(TraceSession session, int durationMs) =>
      _updateSession(
        session,
        (current) => _withDuration(current, durationMs),
        runningOnly: true,
      );

  Future<TraceSession> saveDetails(
    TraceSession session, {
    required TraceDetails details,
    int? durationMs,
  }) => _updateSession(session, (current) async {
    await _checkDetails(current.sceneId, details, previous: current);
    final edited = current.copyWith(
      itemId: Value(details.itemId),
      tagIdsJson: _encodeTags(details.tagIds),
      note: details.note.trim(),
      version: _nextVersion(current.version),
    );
    return durationMs == null ? edited : _withDuration(edited, durationMs);
  });

  Future<TraceSession> discard(TraceSession session) =>
      _updateSession(session, (current) {
        return _withDuration(
          current,
          (current.endedMs ?? current.startedMs) - current.startedMs,
        ).copyWith(
          deleted: true,
          itemId: const Value(null),
          tagIdsJson: '[]',
          note: '',
        );
      });

  String _encodeTags(Set<String> tagIds) => jsonEncode(tagIds.toList()..sort());

  Future<void> _checkDetails(
    String sceneId,
    TraceDetails details, {
    TraceSession? previous,
  }) async {
    final itemId = details.itemId;
    if (itemId != null &&
        itemId != previous?.itemId &&
        await (db.select(db.traceItems)..where(
                  (i) =>
                      i.id.equals(itemId) &
                      i.sceneId.equals(sceneId) &
                      i.archived.equals(false),
                ))
                .getSingleOrNull() ==
            null) {
      throw StateError('所选事项已归档或不属于这个场景');
    }
    final added = details.tagIds.difference(
      previous == null ? {} : decodeTraceTags(previous.tagIdsJson),
    );
    if (added.isEmpty) return;
    final tags = await (db.select(
      db.traceTags,
    )..where((t) => t.id.isIn(added) & t.archived.equals(false))).get();
    if (tags.length != added.length) throw StateError('所选标签已归档，请重新选择');
  }

  TraceSession _withDuration(TraceSession session, int durationMs) {
    if (durationMs < 0) throw ArgumentError('结束时间早于开始时间');
    return session
        .copyWith(
          endedMs: Value(session.startedMs + durationMs),
          version: _nextVersion(session.version),
        )
        .withClockOf(null);
  }

  Future<TraceSession?> sessionById(String id) => (db.select(
    db.traceSessions,
  )..where((s) => s.id.equals(id) & s.deleted.equals(false))).getSingleOrNull();

  Future<TraceSession> _updateSession(
    TraceSession expected,
    FutureOr<TraceSession> Function(TraceSession) update, {
    bool runningOnly = false,
  }) => db.transaction(() async {
    final current = await sessionById(expected.id);
    if (current == null) throw StateError('这条计时已移除');
    if (runningOnly && current.endedMs != null) throw StateError('这条计时已经结束');
    if (!runningOnly && current.version != expected.version) {
      throw StateError('记录已更新，请重新打开');
    }
    final updated = await update(current);
    await db.update(db.traceSessions).replace(updated);
    return updated;
  });

  Future<TraceData?> mergeBackup(TraceData remote) => db.transaction(() async {
    final local = await _read(includeDeleted: true);
    var upload = false;
    late final TraceData snapshot;
    await db.batch((batch) {
      List<T> merge<T extends Insertable<T>>(
        TableInfo<Table, T> table,
        List<T> kept,
        List<T> received,
        String Function(T) identity,
        int Function(T) version, {
        int Function(T)? priority,
        T Function(T?, T)? keepLocalFields,
      }) {
        final rows = {for (final row in kept) identity(row): row};
        final changes = <T>[];
        for (final incoming in received) {
          final id = identity(incoming);
          final previous = rows[id];
          final rank = previous == null || priority == null
              ? 0
              : priority(incoming) - priority(previous);
          if (previous == null ||
              rank > 0 ||
              (rank == 0 && version(incoming) > version(previous))) {
            final merged =
                keepLocalFields?.call(previous, incoming) ?? incoming;
            rows[id] = merged;
            changes.add(merged);
          } else if (rank < 0 || version(incoming) < version(previous)) {
            upload = true;
          } else if (!_sameBackupRow(previous, incoming)) {
            throw const FormatException('时迹备份有同版本冲突，未覆盖本机记录');
          }
        }
        if (rows.length > received.length) upload = true;
        if (changes.isNotEmpty) batch.insertAllOnConflictUpdate(table, changes);
        return rows.values.toList();
      }

      for (final item in remote.items) {
        final previous = local.itemById[item.id];
        if (previous != null && previous.sceneId != item.sceneId) {
          throw const FormatException('事项所属场景冲突');
        }
      }
      snapshot = TraceData(
        merge(
          db.traceScenes,
          local.scenes,
          remote.scenes,
          (row) => row.id,
          (row) => row.version,
        ),
        merge(
          db.traceItems,
          local.items,
          remote.items,
          (row) => row.id,
          (row) => row.version,
        ),
        merge(
          db.traceTags,
          local.tags,
          remote.tags,
          (row) => row.id,
          (row) => row.version,
        ),
        merge(
          db.traceSessions,
          local.sessions,
          remote.sessions,
          (row) => row.id,
          (row) => row.version,
          priority: (row) => row.deleted
              ? 2
              : row.endedMs != null
              ? 1
              : 0,
          keepLocalFields: (previous, incoming) {
            if (previous == null) return incoming;
            if (previous.sceneId != incoming.sceneId ||
                previous.startedMs != incoming.startedMs) {
              throw const FormatException('备份中的计时起点与本机记录冲突');
            }
            return incoming.endedMs == null && !incoming.deleted
                ? incoming.withClockOf(previous)
                : incoming;
          },
        ),
      );
    });
    return upload ? snapshot : null;
  });

  bool _sameBackupRow(Object a, Object b) {
    if (a is TraceSession && b is TraceSession) {
      return a.withClockOf(null) == b.withClockOf(null);
    }
    return a == b;
  }

  int _nextVersion(int? previous) =>
      math.max(DateTime.now().microsecondsSinceEpoch, (previous ?? 0) + 1);
}
