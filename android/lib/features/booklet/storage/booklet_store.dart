import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:torrid/core/models/mood.dart';
import 'package:torrid/core/services/storage/app_database.dart';
import 'package:torrid/core/services/storage/user_data_sync.dart';
import 'package:torrid/core/utils/serialization.dart';
import 'package:torrid/core/utils/util.dart';
import 'package:torrid/features/booklet/models/record.dart';
import 'package:torrid/features/booklet/models/style.dart';
import 'package:torrid/features/booklet/models/task.dart';
import 'package:torrid/features/booklet/utils/checkin_stats.dart';

class BookletStore {
  BookletStore(this.db);

  final AppDatabase db;

  SimpleSelectStatement<BookletRecords, BookletRecord> _records() =>
      db.select(db.bookletRecords)
        ..orderBy([(row) => OrderingTerm.desc(row.date)]);

  Stream<List<Style>> watchStyles() => db
      .select(db.bookletStyles)
      .watch()
      .map((rows) => rows.map(_style).toList());

  Stream<List<Record>> watchRecords() =>
      _records().watch().map((rows) => rows.map(_record).toList());

  Future<List<Style>> styles() async =>
      (await db.select(db.bookletStyles).get()).map(_style).toList();

  Future<List<Record>> records() async =>
      (await _records().get()).map(_record).toList();

  Style _style(BookletStyle row) => Style(
    id: row.id,
    startDate: dateFromJson(row.startDate),
    tasks: [
      for (final task in jsonDecode(row.tasks) as List)
        Task.fromJson(task as Map<String, dynamic>),
    ],
    updatedAt: row.updatedAt,
    validCheckIn: 0,
    fullyDone: 0,
    longestStreak: 0,
    longestFullyStreak: 0,
  );

  Record _record(BookletRecord row) => Record(
    id: row.id,
    styleId: row.styleId,
    date: dateFromJson(row.date),
    message: row.message,
    taskCompletion: (jsonDecode(row.taskCompletion) as Map)
        .cast<String, bool>(),
    mood: const MoodTypeConverter().fromJson(row.mood),
    updatedAt: row.updatedAt,
  );

  BookletStyle _styleRow(Style style) => BookletStyle(
    id: style.id,
    startDate: dateToJson(style.startDate),
    tasks: jsonEncode(style.tasks),
    updatedAt: style.updatedAt!,
  );

  BookletRecord _recordRow(Record record) => BookletRecord(
    id: record.id,
    styleId: record.styleId,
    date: dateToJson(record.date),
    message: record.message,
    taskCompletion: jsonEncode(record.taskCompletion),
    mood: record.mood?.name,
    updatedAt: record.updatedAt!,
  );

  bool _matchesStyle(Record record, Style? style) =>
      style != null &&
      record.taskCompletion.length == style.tasks.length &&
      style.tasks.every((task) => record.taskCompletion.containsKey(task.id));

  Future<bool> hasDataToday() async {
    final today = dateToJson(getTodayDate());
    return (await db
            .customSelect(
              'SELECT 1 FROM booklet_styles WHERE start_date = ? '
              'UNION ALL SELECT 1 FROM booklet_records WHERE date = ? LIMIT 1',
              variables: [Variable(today), Variable(today)],
            )
            .getSingleOrNull()) !=
        null;
  }

  Future<void> putRecord({required String styleId, required Record record}) =>
      db.transaction(() async {
        final style = await (db.select(
          db.bookletStyles,
        )..where((row) => row.id.equals(styleId))).getSingleOrNull();
        if (record.styleId != styleId ||
            !_matchesStyle(record, style == null ? null : _style(style))) {
          throw StateError('打卡样式已变化，请重新打开');
        }
        final previous =
            await (_records()..where(
                  (row) =>
                      row.styleId.equals(styleId) &
                      row.date.equals(dateToJson(record.date)),
                ))
                .getSingleOrNull();
        if ((previous != null && previous.id != record.id) ||
            previous?.updatedAt.microsecondsSinceEpoch !=
                record.updatedAt?.microsecondsSinceEpoch) {
          throw StateError('当天打卡已变化，请重试');
        }
        final empty =
            record.message.isEmpty &&
            record.mood == null &&
            record.taskCompletion.values.every((flag) => !flag);
        if (empty) {
          if (previous == null) return;
          await db.deleteVersion(
            'booklet',
            'records',
            record.id,
            previous.updatedAt,
          );
          await (db.delete(
            db.bookletRecords,
          )..where((row) => row.id.equals(record.id))).go();
          return;
        }
        final version =
            previous?.updatedAt ??
            await db.deletedAt('booklet', 'records', record.id);
        await db
            .into(db.bookletRecords)
            .insertOnConflictUpdate(
              _recordRow(record.copyWith(updatedAt: nextUserDataTime(version))),
            );
      });

  Future<void> createStyle({
    required Style style,
    required bool replaceToday,
  }) => db.transaction(() async {
    if (style.tasks.isEmpty ||
        style.tasks.length > 5 ||
        style.tasks.any((task) => task.title.trim().isEmpty) ||
        style.tasks.map((task) => task.id).toSet().length !=
            style.tasks.length) {
      throw const FormatException('样式需要 1–5 个不同的非空任务');
    }
    final today = dateToJson(getTodayDate());
    final removedStyles = await (db.select(
      db.bookletStyles,
    )..where((row) => row.startDate.equals(today))).get();
    final styleIds = removedStyles.map((row) => row.id).toList();
    final removedRecords =
        await (_records()..where(
              (row) => row.date.equals(today) | row.styleId.isIn(styleIds),
            ))
            .get();
    if (!replaceToday &&
        (removedStyles.isNotEmpty || removedRecords.isNotEmpty)) {
      throw StateError('今天的样式或打卡已变化，请重新确认');
    }
    final versions = {
      for (final item in removedStyles) item.id: item.updatedAt,
    };
    for (final item in removedRecords) {
      await db.deleteVersion('booklet', 'records', item.id, item.updatedAt);
      if (versions[item.styleId]?.isBefore(item.updatedAt) == true) {
        versions[item.styleId] = item.updatedAt;
      }
    }
    for (final entry in versions.entries) {
      await db.deleteVersion('booklet', 'styles', entry.key, entry.value);
    }
    await (db.delete(
      db.bookletRecords,
    )..where((row) => row.id.isIn(removedRecords.map((item) => item.id)))).go();
    await (db.delete(
      db.bookletStyles,
    )..where((row) => row.id.isIn(styleIds))).go();
    await db
        .into(db.bookletStyles)
        .insert(_styleRow(style.copyWith(updatedAt: nextUserDataTime())));
  });

  Future<Set<String>> syncImages(UserDataBatch sync) =>
      db.transaction(() async {
        return syncAttachmentPaths(
          {
            for (final style in await styles())
              style.id: (
                updatedAt: style.updatedAt!,
                paths: style.tasks.map((task) => task.image),
              ),
          },
          sync.rows('styles'),
          await db.deletionVersions(sync, 'styles'),
          (json) =>
              (json['tasks'] as List).map((task) => task['image'] as String),
        );
      });

  Future<void> syncData(
    UserDataBatch sync, {
    required String address,
  }) => db.transaction(() async {
    final deletedRecords = await db.deletionVersions(
      sync,
      'records',
      save: true,
    );
    final deletedStyles = await db.deletionVersions(sync, 'styles', save: true);
    final oldStyles = {
      for (final row in await (db.select(
        db.bookletStyles,
      )..where((row) => row.id.isIn(sync.affectedIds('styles')))).get())
        row.id: row,
    };
    final oldRecords = {
      for (final row
          in await (_records()
                ..where((row) => row.id.isIn(sync.affectedIds('records'))))
              .get())
        row.id: row,
    };
    final stylesToRemove = [
      for (final row in oldStyles.values)
        if (isDeleted(row.updatedAt, deletedStyles[row.id])) row.id,
    ];
    final recordsToRemove = {
      for (final row in oldRecords.values)
        if (isDeleted(row.updatedAt, deletedRecords[row.id])) row.id,
    };
    final styleWrites = <BookletStyle>[];
    final recordWrites = <BookletRecord>[];
    for (final json in sync.rows('styles').values) {
      final incoming = Style.fromJson(json);
      if (!isDeleted(incoming.updatedAt!, deletedStyles[incoming.id]) &&
          oldStyles[incoming.id]?.updatedAt.isAfter(incoming.updatedAt!) !=
              true) {
        styleWrites.add(_styleRow(incoming));
      }
    }
    for (final json in sync.rows('records').values) {
      final incoming = Record.fromJson(json);
      final old = oldRecords[incoming.id];
      if (isDeleted(incoming.updatedAt!, deletedRecords[incoming.id]) ||
          old?.updatedAt.isAfter(incoming.updatedAt!) == true) {
        continue;
      }
      final row = _recordRow(incoming);
      if (old != null && (old.styleId != row.styleId || old.date != row.date)) {
        recordsToRemove.add(row.id);
      }
      recordWrites.add(row);
    }
    final relatedStyles = {
      ...styleWrites.map((row) => row.id),
      ...recordWrites.map((row) => row.styleId),
      ...stylesToRemove,
    };
    await db.batch((batch) {
      batch.deleteWhere(
        db.bookletRecords,
        (row) => row.id.isIn(recordsToRemove),
      );
      batch.deleteWhere(db.bookletStyles, (row) => row.id.isIn(stylesToRemove));
      batch.insertAllOnConflictUpdate(db.bookletStyles, styleWrites);
      batch.insertAllOnConflictUpdate(db.bookletRecords, recordWrites);
    });
    if (relatedStyles.isNotEmpty) {
      final existing = {
        for (final row in await (db.select(
          db.bookletStyles,
        )..where((row) => row.id.isIn(relatedStyles))).get())
          row.id: _style(row),
      };
      for (final row
          in await (_records()..where((row) => row.styleId.isIn(relatedStyles)))
              .get()) {
        if (!_matchesStyle(_record(row), existing[row.styleId])) {
          throw const FormatException('打卡记录与样式不一致，请重试同步');
        }
      }
    }
    await db.saveSyncCursor(address, 'booklet', sync.cursor);
  });

  Future<({Map<String, dynamic> data, Iterable<String> images})> snapshot() =>
      db.transaction(() async {
        final allRecords = await records();
        final allStyles = stylesWithStats(await styles(), allRecords);
        return (
          data: {
            'sync_version': 2,
            'styles': allStyles.map((style) => style.toJson()).toList(),
            'records': allRecords.map((record) => record.toJson()).toList(),
            'tombstones': await db.tombstones('booklet'),
          },
          images: allStyles.expand(
            (style) => style.tasks.map((task) => task.image),
          ),
        );
      });
}

List<Style> stylesWithStats(Iterable<Style> styles, Iterable<Record> records) {
  final grouped = <String, List<Record>>{};
  for (final record in records) {
    (grouped[record.styleId] ??= []).add(record);
  }
  return [
    for (final style in styles)
      style.copyWith(
        validCheckIn: grouped[style.id]?.length ?? 0,
        fullyDone: countFullyDone(grouped[style.id] ?? const []),
        longestStreak: longestStreak(grouped[style.id] ?? const []),
        longestFullyStreak: longestFullyStreak(grouped[style.id] ?? const []),
      ),
  ];
}
