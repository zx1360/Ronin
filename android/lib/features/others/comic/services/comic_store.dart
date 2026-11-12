import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/core/services/storage/app_database.dart';
import 'package:torrid/features/others/comic/models/chapter_info.dart';
import 'package:torrid/features/others/comic/models/comic_download_task.dart';
import 'package:torrid/features/others/comic/models/comic_info.dart';
import 'package:torrid/features/others/comic/models/comic_preference.dart';

final comicStoreProvider = Provider(
  (ref) => ComicStore(ref.watch(appDatabaseProvider)),
);

class ComicStore {
  ComicStore(this.db);

  final AppDatabase db;

  ComicInfo _comic(ComicRow row) => ComicInfo(
    id: row.id,
    comicName: row.name,
    coverImage: row.coverImage,
    chapterCount: row.chapterCount,
    imageCount: row.imageCount,
    isPublic: row.isPublic,
    readed: row.readed,
  );

  ComicRow _comicRow(ComicInfo comic) => ComicRow(
    id: comic.id,
    name: comic.comicName,
    coverImage: comic.coverImage,
    chapterCount: comic.chapterCount,
    imageCount: comic.imageCount,
    isPublic: comic.isPublic,
    readed: comic.readed,
  );

  ChapterInfo _chapter(ComicChapterRow row) => ChapterInfo(
    id: row.id,
    comicId: row.comicId,
    chapterIndex: row.chapterIndex,
    dirName: row.dirName,
    images: (jsonDecode(row.images) as List).cast<Map<String, dynamic>>(),
  );

  ComicChapterRow _chapterRow(ChapterInfo chapter) => ComicChapterRow(
    id: chapter.id,
    comicId: chapter.comicId,
    chapterIndex: chapter.chapterIndex,
    dirName: chapter.dirName,
    images: jsonEncode(chapter.images),
  );

  Future<List<ComicInfo>> comics() async =>
      (await db.select(db.comicCatalog).get()).map(_comic).toList();

  Stream<List<ComicInfo>> watchComics() => db
      .select(db.comicCatalog)
      .watch()
      .map((rows) => rows.map(_comic).toList());

  Future<ComicInfo?> comic(String id) async {
    final row = await (db.select(
      db.comicCatalog,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    return row == null ? null : _comic(row);
  }

  Future<List<ChapterInfo>> chapters() async =>
      (await db.select(db.comicChapters).get()).map(_chapter).toList();

  Stream<List<ChapterInfo>> watchChapters(String comicId) =>
      (db.select(db.comicChapters)
            ..where((row) => row.comicId.equals(comicId))
            ..orderBy([
              (row) => OrderingTerm.asc(row.chapterIndex),
              (row) => OrderingTerm.asc(row.id),
            ]))
          .watch()
          .map((rows) => rows.map(_chapter).toList());

  SimpleSelectStatement<ComicProgress, ComicProgressRow> _progress(
    String comicId,
  ) => db.select(db.comicProgress)..where((row) => row.comicId.equals(comicId));

  Stream<ComicPreference> watchProgress(String comicId) =>
      _progress(comicId).watchSingleOrNull().map(
        (row) => ComicPreference(
          comicId: comicId,
          chapterIndex: row?.chapterIndex ?? 0,
          flipReading: row?.flipReading ?? false,
        ),
      );

  Future<void> updateProgress(
    String comicId, {
    int? chapterIndex,
    bool? flipReading,
  }) => db.transaction(() async {
    final old = await _progress(comicId).getSingleOrNull();
    await db
        .into(db.comicProgress)
        .insertOnConflictUpdate(
          ComicProgressRow(
            comicId: comicId,
            chapterIndex: chapterIndex ?? old?.chapterIndex ?? 0,
            flipReading: flipReading ?? old?.flipReading ?? false,
          ),
        );
  });

  Future<void> syncFields(ComicInfo server) =>
      (db.update(
        db.comicCatalog,
      )..where((row) => row.id.equals(server.id))).write(
        ComicCatalogCompanion(
          isPublic: server.isPublic == null
              ? const Value.absent()
              : Value(server.isPublic),
          readed: server.readed == null
              ? const Value.absent()
              : Value(server.readed),
          chapterCount: Value(server.chapterCount),
          imageCount: Value(server.imageCount),
        ),
      );

  Future<void> saveComic(ComicInfo comic, List<ChapterInfo> chapters) =>
      db.batch((batch) {
        batch.insert(
          db.comicCatalog,
          _comicRow(comic),
          onConflict: DoUpdate((_) => _comicRow(comic)),
        );
        batch.deleteWhere(
          db.comicChapters,
          (row) =>
              row.comicId.equals(comic.id) &
              row.id.isNotIn(chapters.map((chapter) => chapter.id)),
        );
        batch.insertAllOnConflictUpdate(
          db.comicChapters,
          chapters.map(_chapterRow),
        );
      });

  Future<void> replaceCatalog(
    List<ComicInfo> comics,
    List<ChapterInfo> chapters,
  ) => db.transaction(() async {
    final kept = comics.map((comic) => comic.id).toSet();
    final removed = (await db.select(db.comicCatalog).get())
        .where((comic) => !kept.contains(comic.id))
        .map((comic) => comic.id);
    await db.batch((batch) {
      batch.deleteWhere(db.comicProgress, (row) => row.comicId.isIn(removed));
      batch.deleteWhere(db.comicCatalog, (row) => row.id.isIn(removed));
      batch.deleteWhere(
        db.comicChapters,
        (row) => row.id.isNotIn(chapters.map((chapter) => chapter.id)),
      );
      batch.insertAllOnConflictUpdate(db.comicCatalog, comics.map(_comicRow));
      batch.insertAllOnConflictUpdate(
        db.comicChapters,
        chapters.map(_chapterRow),
      );
    });
  });

  Future<void> removeComic(String id) => db.batch((batch) {
    batch.deleteWhere(db.comicProgress, (row) => row.comicId.equals(id));
    batch.deleteWhere(db.comicCatalog, (row) => row.id.equals(id));
  });

  Future<List<ComicDownloadTask>> downloads() async => [
    for (final row in await (db.select(
      db.comicDownloads,
    )..orderBy([(row) => OrderingTerm.desc(row.createdAtMs)])).get())
      ComicDownloadTask.fromJson(jsonDecode(row.task) as Map<String, dynamic>),
  ];

  Future<void> saveDownloads(List<ComicDownloadTask> tasks) =>
      db.batch((batch) {
        batch.deleteWhere(
          db.comicDownloads,
          (row) => row.comicId.isNotIn(tasks.map((task) => task.comicId)),
        );
        batch.insertAllOnConflictUpdate(db.comicDownloads, [
          for (final task in tasks)
            ComicDownloadRow(
              comicId: task.comicId,
              createdAtMs: task.createdAtMs,
              task: jsonEncode(task),
            ),
        ]);
      });
}
