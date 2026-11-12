import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/core/services/debug/logging_service.dart';
import 'package:torrid/core/services/io/io_service.dart';
import 'package:torrid/core/services/storage/app_database.dart';
import 'package:torrid/features/essay/models/essay.dart';
import 'package:torrid/features/essay/models/essay_draft.dart';

final essayDraftStoreProvider = Provider(
  (ref) => EssayDraftStore(ref.watch(appDatabaseProvider)),
);

final essayDraftsProvider = StreamProvider.autoDispose<List<EssayDraft>>(
  (ref) => ref.watch(essayDraftStoreProvider).watchDrafts(),
);

class EssayDraftStore {
  final AppDatabase db;

  EssayDraftStore(this.db);

  EssayDraft _decode(EssayDraftRow row) => EssayDraft(
    essay: Essay.fromJson(jsonDecode(row.essay) as Map<String, dynamic>),
    original: row.original == null
        ? null
        : Essay.fromJson(jsonDecode(row.original!) as Map<String, dynamic>),
    updatedAt: row.editedAt.toLocal(),
  );

  Stream<List<EssayDraft>> watchDrafts() =>
      (db.select(db.essayDrafts)
            ..orderBy([(row) => OrderingTerm.desc(row.editedAt)]))
          .watch()
          .map((rows) => rows.map(_decode).toList());

  Future<EssayDraft?> forEssay(String id) async {
    final row = await (db.select(
      db.essayDrafts,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    return row == null ? null : _decode(row);
  }

  Future<void> save(EssayDraft draft) => db.transaction(() async {
    final id = draft.essay.id;
    if (!draft.hasContent && await forEssay(id) == null) return;
    await db
        .into(db.essayDrafts)
        .insertOnConflictUpdate(
          EssayDraftRow(
            id: id,
            editedAt: draft.updatedAt,
            essay: jsonEncode(draft.essay),
            original: draft.original == null
                ? null
                : jsonEncode(draft.original),
          ),
        );
  });

  Future<void> remove(String id) =>
      (db.delete(db.essayDrafts)..where((row) => row.id.equals(id))).go();

  Future<String> importImage(String draftId, File source) =>
      IoService.importUserImage('essay_drafts/$draftId', source);

  Future<Essay> publish(
    Essay essay,
    Future<Essay> Function(Essay) writeEssay,
  ) async {
    final images = <String>[];
    final imported = <String>[];
    try {
      for (final image in essay.imgs) {
        if (image.startsWith('essay_drafts/')) {
          if (!image.startsWith('essay_drafts/${essay.id}/')) {
            throw const FormatException('图片不属于当前草稿');
          }
          final key = await IoService.importUserImage(
            'img_storage/essay',
            await IoService.userFile(image),
          );
          imported.add(key);
          images.add(key);
        } else {
          images.add(image);
        }
      }
      return await writeEssay(essay.copyWith(imgs: images));
    } catch (_) {
      for (final key in imported) {
        try {
          await IoService.deleteUserFile(key);
        } catch (error) {
          AppLogger().warning('清理未发布的随笔图片失败: $error');
        }
      }
      rethrow;
    }
  }

  Future<void> cleanImages(String id) =>
      IoService.deleteUserDirectory('essay_drafts/$id');
}
