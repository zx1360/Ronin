import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:torrid/core/services/storage/app_database.dart';
import 'package:torrid/features/others/gallery/models/batch_data.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/models/tag.dart';

part 'gallery_operation_store.dart';

class GalleryDatabaseService {
  GalleryDatabaseService(this.db);

  final AppDatabase db;

  JoinedSelectStatement<HasResultSet, dynamic> _assets(
    Expression<bool> condition,
  ) {
    final rows = db.galleryAssets;
    return (db.select(rows).join([
        innerJoin(db.galleryLibrary, const Constant(true)),
      ])
      ..where(condition)
      ..orderBy([
        OrderingTerm.asc(rows.capturedAt),
        OrderingTerm.asc(rows.id),
      ]));
  }

  List<MediaAsset> _readAssets(List<TypedResult> rows) =>
      rows.map(_joinedAsset).toList();

  MediaAsset _joinedAsset(TypedResult row) => _asset(
    row.readTable(db.galleryAssets),
    row.readTable(db.galleryLibrary).id,
  );

  MediaAsset _asset(GalleryAssetRow row, String libraryId) => MediaAsset(
    id: row.id,
    localLibraryId: libraryId,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    capturedAt: row.capturedAt,
    filePath: row.filePath,
    thumbPath: row.thumbPath,
    previewPath: row.previewPath,
    hash: row.hash,
    sizeBytes: row.sizeBytes,
    mimeType: row.mimeType,
    isDeleted: row.isDeleted,
    syncCount: row.syncCount,
    groupId: row.groupId,
    message: row.message,
    editParams: row.editParams,
  );

  GalleryAssetRow _assetRow(MediaAsset asset, Set<String> availableGroups) =>
      GalleryAssetRow(
        id: asset.id,
        createdAt: asset.createdAt,
        updatedAt: asset.updatedAt,
        capturedAt: asset.capturedAt,
        filePath: asset.filePath,
        thumbPath: asset.thumbPath,
        previewPath: asset.previewPath,
        hash: asset.hash,
        sizeBytes: asset.sizeBytes,
        mimeType: asset.mimeType,
        isDeleted: asset.isDeleted,
        syncCount: asset.syncCount,
        groupId: availableGroups.contains(asset.groupId) ? asset.groupId : null,
        message: asset.message,
        editParams: asset.editParams,
      );

  Stream<List<MediaAsset>> watchMediaAssets() =>
      _assets(db.galleryAssets.groupId.isNull()).watch().map(_readAssets);

  Future<List<MediaAsset>> getMediaAssets({
    bool includeGroupMembers = false,
  }) async => _readAssets(
    await _assets(
      includeGroupMembers
          ? const Constant(true)
          : db.galleryAssets.groupId.isNull(),
    ).get(),
  );

  Future<MediaAsset?> getMediaAssetById(String id) async {
    final row = await _assets(db.galleryAssets.id.equals(id)).getSingleOrNull();
    return row == null ? null : _joinedAsset(row);
  }

  Future<List<MediaAsset>> getGroupMembers(String leadId) async =>
      _readAssets(await _assets(db.galleryAssets.groupId.equals(leadId)).get());

  Stream<List<MediaAsset>> watchGroup(String leadId) =>
      _assets(
        db.galleryAssets.id.equals(leadId) |
            db.galleryAssets.groupId.equals(leadId),
      ).watch().map((rows) {
        final group = _readAssets(rows);
        final index = group.indexWhere((asset) => asset.id == leadId);
        if (index > 0) group.insert(0, group.removeAt(index));
        return group;
      });

  Stream<Map<String, int>> watchGroupSizes() => db
      .customSelect(
        'SELECT group_id, COUNT(*) + 1 AS size FROM gallery_assets '
        'WHERE group_id IS NOT NULL GROUP BY group_id',
        readsFrom: {db.galleryAssets},
      )
      .watch()
      .map(
        (rows) => {
          for (final row in rows)
            row.read<String>('group_id'): row.read<int>('size'),
        },
      );

  Future<void> storeBatch(BatchData data) => db.transaction(() async {
    await _requireBinding();
    final assets = data.medias;
    if (assets.isEmpty) return;
    final current = await _currentLead();
    final available = {
      ...assets.map((asset) => asset.id),
      ...await getCachedMediaIds(assets.map((asset) => asset.groupId).nonNulls),
    };
    await db.batch(
      (batch) => batch.insertAllOnConflictUpdate(
        db.galleryAssets,
        assets.map((asset) => _assetRow(asset, available)),
      ),
    );
    await syncTagsCache(data.tags, preserveOperations: false);
    final tagsByMedia = <String, List<String>>{
      for (final asset in assets) asset.id: [],
    };
    for (final link in data.links) {
      final tags = tagsByMedia[link.mediaId];
      if (tags != null) tags.add(link.tagId);
    }
    await _replaceMediaTags(tagsByMedia);
    if (current != null) await _restoreLead(current);
  });

  /// 在线写入只覆盖已缓存的媒体。
  Future<void> updateMediaAssetsLocal(
    List<MediaAsset> assets, {
    bool preserveOperations = false,
    String? expectedLibraryId,
    Map<String, List<String>>? tagIdsByMedia,
  }) => db.transaction(() async {
    if (expectedLibraryId != null && await libraryId() != expectedLibraryId) {
      return;
    }
    if (preserveOperations && await _hasOperations()) return;
    final cached = (await getCachedMediaIds(
      assets.map((asset) => asset.id),
    )).toSet();
    if (cached.isEmpty) return;
    final changed = assets.where((asset) => cached.contains(asset.id));
    final groups = (await getCachedMediaIds(
      changed.map((asset) => asset.groupId).nonNulls,
    )).toSet();
    await db.batch(
      (batch) => batch.insertAllOnConflictUpdate(
        db.galleryAssets,
        changed.map((asset) => _assetRow(asset, groups)),
      ),
    );
    if (tagIdsByMedia != null) {
      await _replaceMediaTags({
        for (final id in cached)
          if (tagIdsByMedia[id] case final ids?) id: ids,
      });
    }
  });

  Future<List<String>> getCachedMediaIds(Iterable<String> ids) async {
    final table = db.galleryAssets;
    return [
      for (final chunk in _chunks(ids.toSet()))
        for (final row
            in await (db.selectOnly(table)
                  ..addColumns([table.id])
                  ..where(table.id.isIn(chunk)))
                .get())
          row.read(table.id)!,
    ];
  }

  Future<Map<String, MediaAsset>> getMediaAssetsByIds(
    Iterable<String> ids,
  ) async => {
    for (final chunk in _chunks(ids.toSet()))
      for (final asset in _readAssets(
        await _assets(db.galleryAssets.id.isIn(chunk)).get(),
      ))
        asset.id: asset,
  };

  Future<Map<String, Set<String>>> getMediaTagIdsByMedia(
    Iterable<String> ids,
  ) async {
    final result = <String, Set<String>>{};
    for (final chunk in _chunks(ids.toSet())) {
      final rows = await (db.select(
        db.galleryLinks,
      )..where((row) => row.mediaId.isIn(chunk))).get();
      for (final row in rows) {
        (result[row.mediaId] ??= {}).add(row.tagId);
      }
    }
    return result;
  }

  Tag _tag(GalleryTagRow row) => Tag(
    id: row.id,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    name: row.name,
    parentId: row.parentId,
    fullPath: row.fullPath,
    isFavorite: row.isFavorite,
    mediaCount: row.mediaCount,
  );

  GalleryTagRow _tagRow(Tag tag) => GalleryTagRow(
    id: tag.id,
    createdAt: tag.createdAt,
    updatedAt: tag.updatedAt,
    name: tag.name,
    parentId: tag.parentId,
    fullPath: tag.fullPath,
    isFavorite: tag.isFavorite,
    mediaCount: tag.mediaCount,
  );

  SimpleSelectStatement<GalleryTags, GalleryTagRow> _tags() =>
      db.select(db.galleryTags)
        ..orderBy([(row) => OrderingTerm.asc(row.fullPath)]);

  Future<List<Tag>> getAllTags() async =>
      (await _tags().get()).map(_tag).toList();

  Stream<List<Tag>> watchTags() =>
      _tags().watch().map((rows) => rows.map(_tag).toList());

  Future<Tag?> getTag(String id) async {
    final row = await (_tags()..where((row) => row.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _tag(row);
  }

  Future<void> syncTagsCache(
    List<Tag> tags, {
    bool preserveOperations = true,
  }) => db.transaction(() async {
    if (preserveOperations && await _hasOperations()) return;
    await _requireBinding();
    await db.batch((batch) {
      batch.insertAllOnConflictUpdate(db.galleryTags, tags.map(_tagRow));
      batch.deleteWhere(
        db.galleryTags,
        (row) => row.id.isNotIn(tags.map((tag) => tag.id)),
      );
    });
  });

  Future<void> upsertTagLocal(Tag tag) =>
      db.into(db.galleryTags).insertOnConflictUpdate(_tagRow(tag));

  Future<void> deleteTagsLocal(Iterable<String> ids) =>
      (db.delete(db.galleryTags)..where((row) => row.id.isIn(ids))).go();

  Future<List<String>> getTagIdsForMedia(String id) async =>
      (await (db.select(
            db.galleryLinks,
          )..where((row) => row.mediaId.equals(id))).get())
          .map((row) => row.tagId)
          .toList();

  Stream<List<Tag>> watchTagsForMedia(String mediaId) {
    final tags = db.galleryTags;
    final links = db.galleryLinks;
    return (db.select(tags).join([
            innerJoin(links, tags.id.equalsExp(links.tagId)),
          ])
          ..where(links.mediaId.equals(mediaId))
          ..orderBy([OrderingTerm.asc(tags.fullPath)]))
        .watch()
        .map((rows) => [for (final row in rows) _tag(row.readTable(tags))]);
  }

  Future<void> _replaceMediaTags(Map<String, List<String>> tagsByMedia) =>
      db.batch((batch) {
        for (final entry in tagsByMedia.entries) {
          batch.deleteWhere(
            db.galleryLinks,
            (row) => row.mediaId.equals(entry.key),
          );
          batch.insertAll(db.galleryLinks, [
            for (final id in entry.value.toSet())
              GalleryLink(mediaId: entry.key, tagId: id),
          ]);
        }
      });

  Future<void> addRemoveMediaTagLinks(
    List<String> mediaIds, {
    List<String> addTagIds = const [],
    List<String> removeTagIds = const [],
  }) => db.transaction(() async {
    final cached = await getCachedMediaIds(mediaIds);
    await db.batch((batch) {
      for (final chunk in _chunks(cached)) {
        batch.deleteWhere(
          db.galleryLinks,
          (row) => row.mediaId.isIn(chunk) & row.tagId.isIn(removeTagIds),
        );
        batch.insertAll(db.galleryLinks, [
          for (final mediaId in chunk)
            for (final tagId in addTagIds)
              GalleryLink(mediaId: mediaId, tagId: tagId),
        ], mode: InsertMode.insertOrIgnore);
      }
    });
  });

  Stream<Set<String>> watchMediaIdsWithTags() => db
      .customSelect(
        'SELECT DISTINCT media_id FROM gallery_links',
        readsFrom: {db.galleryLinks},
      )
      .watch()
      .map((rows) => {for (final row in rows) row.read<String>('media_id')});

  Stream<({int media, int tags, int links})> watchCounts() => db
      .customSelect(
        """
    SELECT (SELECT COUNT(*) FROM gallery_assets) AS media,
           (SELECT COUNT(*) FROM gallery_tags) AS tags,
           (SELECT COUNT(*) FROM gallery_links) AS links
    """,
        readsFrom: {db.galleryAssets, db.galleryTags, db.galleryLinks},
      )
      .watchSingle()
      .map(
        (row) => (
          media: row.read<int>('media'),
          tags: row.read<int>('tags'),
          links: row.read<int>('links'),
        ),
      );

  Future<String?> libraryId() async =>
      (await db.select(db.galleryLibrary).getSingleOrNull())?.id;

  Future<void> bindLibrary(String id) => db.transaction(() async {
    final current = await libraryId();
    if (current == id) return;
    if (current != null) {
      throw StateError('本机画廊属于另一图库，请切回原图库。本机修改已保留');
    }
    await db
        .into(db.galleryLibrary)
        .insert(GalleryLibraryCompanion.insert(slot: const Value(1), id: id));
    await db
        .into(db.galleryPositions)
        .insert(GalleryPositionsCompanion.insert(slot: const Value(1)));
  });

  Future<void> _requireBinding() async {
    if (await libraryId() == null) throw StateError('请先连接服务端图库');
  }

  Stream<int> watchCurrentIndex() => db
      .select(db.galleryPositions)
      .watchSingleOrNull()
      .map((row) => row?.currentIndex ?? 0)
      .distinct();

  Future<void> setCurrentIndex(int value) => db
      .update(db.galleryPositions)
      .write(
        GalleryPositionsCompanion(currentIndex: Value(value < 0 ? 0 : value)),
      );
  Future<void> clearAllData() => db.batch((batch) {
    batch.deleteAll(db.galleryAssets);
    batch.deleteAll(db.galleryTags);
    batch.deleteAll(db.galleryOperations);
    batch.deleteAll(db.galleryLibrary);
  });

  static const _processedQueue = r"""
    WITH ranked AS (
      SELECT id, ROW_NUMBER() OVER (ORDER BY captured_at, id) - 1 AS position
      FROM gallery_assets WHERE group_id IS NULL
    ), touched(id) AS (
      SELECT json_extract(body, '$.media_id') FROM gallery_operations WHERE kind = 'tags'
      UNION
      SELECT value FROM gallery_operations, json_each(body, '$.affected_ids')
      WHERE kind = 'patch'
    ), processed AS (
      SELECT id FROM ranked WHERE position <= MAX(
        COALESCE((SELECT current_index FROM gallery_positions), 0),
        COALESCE((SELECT MAX(ranked.position) FROM ranked JOIN gallery_assets media
          ON ranked.id = COALESCE(media.group_id, media.id)
          JOIN touched ON media.id = touched.id), 0)
      )
    )
  """;

  Stream<({int mediaCount, int deletedCount})> watchProcessedStats() => db
      .customSelect(
        """
        $_processedQueue
        SELECT COUNT(*) AS media_count, COALESCE(SUM(is_deleted), 0) AS deleted_count
        FROM gallery_assets JOIN processed USING (id)
        """,
        readsFrom: {
          db.galleryAssets,
          db.galleryOperations,
          db.galleryPositions,
        },
      )
      .watchSingle()
      .map(
        (row) => (
          mediaCount: row.read<int>('media_count'),
          deletedCount: row.read<int>('deleted_count'),
        ),
      );

  Future<List<MediaAsset>> getProcessedAssets() async {
    final rows = await db.customSelect("""
      $_processedQueue
      SELECT a.*, library.id AS library_id FROM gallery_assets a CROSS JOIN gallery_library library
      WHERE a.id IN (SELECT id FROM processed) OR a.group_id IN (SELECT id FROM processed)
      ORDER BY a.captured_at, a.id
      """).get();
    return [
      for (final row in rows)
        _asset(db.galleryAssets.map(row.data), row.read<String>('library_id')),
    ];
  }
}

Iterable<List<String>> _chunks(Iterable<String> ids) sync* {
  final values = ids.toList();
  for (var start = 0; start < values.length; start += 400) {
    yield values.sublist(start, (start + 400).clamp(0, values.length));
  }
}
