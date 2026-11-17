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
  TraceStore(this.db);

  final AppDatabase db;
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

  Future<void> saveScene({
    TraceScene? scene,
    required String name,
    required int color,
  }) async {
    await db
        .into(db.traceScenes)
        .insertOnConflictUpdate(
          TraceScene(
            id: scene?.id ?? _uuid.v4(),
            name: name,
            color: color,
            archived: scene?.archived ?? false,
            version: _nextVersion(scene?.version),
          ),
        );
  }

  Future<void> saveItem(String sceneId, String name, {TraceItem? item}) async {
    await db
        .into(db.traceItems)
        .insertOnConflictUpdate(
          TraceItem(
            id: item?.id ?? _uuid.v4(),
            sceneId: sceneId,
            name: name,
            archived: item?.archived ?? false,
            version: _nextVersion(item?.version),
          ),
        );
  }

  Future<void> saveTag(String name, {TraceTag? tag}) async {
    await db
        .into(db.traceTags)
        .insertOnConflictUpdate(
          TraceTag(
            id: tag?.id ?? _uuid.v4(),
            name: name,
            archived: tag?.archived ?? false,
            version: _nextVersion(tag?.version),
          ),
        );
  }

  Future<void> archiveScene(TraceScene scene) async => db
      .update(db.traceScenes)
      .replace(
        scene.copyWith(archived: true, version: _nextVersion(scene.version)),
      );
  Future<void> archiveItem(TraceItem item) async => db
      .update(db.traceItems)
      .replace(
        item.copyWith(archived: true, version: _nextVersion(item.version)),
      );
  Future<void> archiveTag(TraceTag tag) async => db
      .update(db.traceTags)
      .replace(
        tag.copyWith(archived: true, version: _nextVersion(tag.version)),
      );

  Future<void> start(TraceScene scene) async {
    final clock = await TraceClock.read();
    await db.transaction(() async {
      final available =
          await (db.select(
                db.traceScenes,
              )..where((s) => s.id.equals(scene.id) & s.archived.equals(false)))
              .getSingleOrNull();
      if (available == null) throw StateError('场景已移除');
      if (await (_running()
                ..where((s) => s.sceneId.equals(scene.id))
                ..limit(1))
              .getSingleOrNull() !=
          null) {
        return;
      }
      await db
          .into(db.traceSessions)
          .insert(
            TraceSessionsCompanion.insert(
              id: _uuid.v4(),
              sceneId: scene.id,
              startedMs: clock.wallMs,
              version: _nextVersion(null),
              bootKey: Value(clock.bootKey),
              anchorElapsedMs: Value(clock.elapsedMs),
              anchorDurationMs: const Value(0),
            ),
          );
    });
  }

  Future<void> resume(TraceSession session, TraceClock clock) =>
      _updateSession(session, (current) {
        return current.copyWith(
          bootKey: Value(clock.bootKey),
          anchorElapsedMs: Value(clock.elapsedMs),
          anchorDurationMs: Value(clock.durationMs(current)),
        );
      });

  Future<void> stop(TraceSession session) async {
    final clock = await TraceClock.read();
    await finish(session, clock.durationMs(session));
  }

  Future<void> finish(TraceSession session, int durationMs) => _updateSession(
    session,
    (current) => _withEnd(current, current.startedMs + durationMs),
  );

  Future<void> saveDetails(
    TraceSession session, {
    required TraceItem? item,
    required Set<String> tagIds,
    required String note,
    required int? durationMs,
  }) => _updateSession(session, (current) {
    if (item != null && item.sceneId != current.sceneId) {
      throw StateError('事项与场景不匹配');
    }
    final edited = current.copyWith(
      itemId: Value(item?.id),
      tagIdsJson: jsonEncode(tagIds.toList()..sort()),
      note: note,
      version: _nextVersion(current.version),
    );
    return durationMs == null
        ? edited
        : _withEnd(edited, edited.startedMs + durationMs);
  });

  Future<void> discard(TraceSession session) =>
      _updateSession(session, (current) {
        return _withEnd(current, current.endedMs ?? current.startedMs).copyWith(
          deleted: true,
          itemId: const Value(null),
          tagIdsJson: '[]',
          note: '',
        );
      });

  TraceSession _withEnd(TraceSession session, int endedMs) => session.copyWith(
    endedMs: Value(endedMs),
    version: _nextVersion(session.version),
    bootKey: const Value(null),
    anchorElapsedMs: const Value(null),
    anchorDurationMs: const Value(null),
  );

  Future<void> _updateSession(
    TraceSession expected,
    TraceSession Function(TraceSession) update,
  ) => db.transaction(() async {
    final current = await (db.select(
      db.traceSessions,
    )..where((s) => s.id.equals(expected.id))).getSingle();
    if (current.deleted || current.version != expected.version) {
      throw StateError('记录已变更，请重新打开');
    }
    await db.update(db.traceSessions).replace(update(current));
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
            rows[id] = incoming;
            changes.add(incoming);
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
        ),
      );
    });
    return upload ? snapshot : null;
  });

  bool _sameBackupRow(Object a, Object b) {
    if (a is TraceSession && b is TraceSession) {
      return a.copyWith(
            bootKey: const Value(null),
            anchorElapsedMs: const Value(null),
            anchorDurationMs: const Value(null),
          ) ==
          b;
    }
    return a == b;
  }

  int _nextVersion(int? previous) =>
      math.max(DateTime.now().microsecondsSinceEpoch, (previous ?? 0) + 1);
}
