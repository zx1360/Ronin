import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:torrid/core/services/storage/storage_types.dart';
import 'package:torrid/features/essay/models/label.dart';
import 'package:torrid/features/trace/trace_defaults.dart';

part 'app_database.g.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(
    LazyDatabase(() async {
      final support = await getApplicationSupportDirectory();
      return NativeDatabase.createInBackground(
        File(p.join(support.path, 'torrid.sqlite')),
      );
    }),
  );
  ref.onDispose(() => unawaited(db.close()));
  return db;
});

@DriftDatabase(
  include: {
    'sync.drift',
    '../../../features/essay/services/essay.drift',
    '../../../features/booklet/storage/booklet.drift',
    '../../../features/chat/services/chat.drift',
    '../../../features/others/comic/services/comic.drift',
    '../../../features/others/gallery/services/gallery.drift',
    '../../../features/trace/trace.drift',
  },
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => transaction(() async {
      await migrator.createAll();
      await into(essayLabels).insert(
        EssayLabel(
          id: Label.hiddenId,
          name: '隐藏',
          parentId: null,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(1, isUtc: true),
        ),
      );
      await _seedTraceScenes();
    }),
    onUpgrade: (migrator, from, to) => transaction(() async {
      if (from < 2) {
        await migrator.createTable(traceScenes);
        await migrator.createTable(traceItems);
        await migrator.createTable(traceTags);
        await migrator.createTable(traceSessions);
        await migrator.createIndex(traceSessionsRunning);
        await _seedTraceScenes();
      } else if (from < 3) {
        await migrator.addColumn(traceSessions, traceSessions.anchorWallMs);
      }
    }),
    beforeOpen: (_) => customStatement('PRAGMA foreign_keys = ON'),
  );

  Future<void> _seedTraceScenes() => batch((batch) {
    batch.insertAll(traceScenes, [
      for (final (index, name) in traceSceneNames.indexed)
        TraceScene(
          id: '00000000-0000-4000-8000-00000000000$index',
          name: name,
          color: traceColors[index],
          archived: false,
          version: 0,
        ),
    ]);
  });

  Future<void> initialize() async {
    await customSelect('SELECT 1').getSingle();
  }
}
