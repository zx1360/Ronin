part of 'gallery_database_service.dart';

class GalleryOperation {
  GalleryOperation({
    required this.seq,
    required this.kind,
    required this.body,
    this.synced = false,
  });

  final int seq;
  final String kind;
  final Map<String, dynamic> body;
  final bool synced;

  factory GalleryOperation.fromRow(GalleryOperationRow row) => GalleryOperation(
    seq: row.seq,
    kind: row.kind,
    synced: row.synced,
    body: jsonDecode(row.body) as Map<String, dynamic>,
  );
}

extension GalleryOperationStore on GalleryDatabaseService {
  Future<bool> _hasOperations() async =>
      (await operations(limit: 1)).isNotEmpty;

  Future<List<GalleryOperation>> operations({
    bool pendingOnly = false,
    int? limit,
  }) async {
    final query = db.select(db.galleryOperations)
      ..orderBy([(row) => OrderingTerm.asc(row.seq)]);
    if (pendingOnly) {
      query.where(
        (row) => row.synced.equals(false) & row.kind.equals('processed').not(),
      );
    }
    if (limit != null) query.limit(limit);
    return (await query.get()).map(GalleryOperation.fromRow).toList();
  }

  Future<void> acknowledge(int seq) =>
      (db.update(db.galleryOperations)..where((row) => row.seq.equals(seq)))
          .write(const GalleryOperationsCompanion(synced: Value(true)));

  Future<GalleryOperation> recordOperation(
    String kind,
    Map<String, dynamic> data,
  ) => db.transaction(() async {
    await _requireBinding();
    final completing =
        await (db.select(db.galleryOperations)
              ..where((row) => row.kind.equals('processed'))
              ..limit(1))
            .getSingleOrNull();
    if (completing != null) throw StateError('请先重试完成上次的标记已处理');
    final body = {...data};
    switch (kind) {
      case 'patch':
        if (body.containsKey('mark_processed')) throw StateError('请使用标记已处理入口');
        await _applyPatch(body);
      case 'tags':
        final id = body['media_id'] as String;
        if (await getMediaAssetById(id) == null) throw StateError('媒体未缓存');
        await _replaceMediaTags({id: (body['tag_ids'] as List).cast<String>()});
      case 'tagCreate':
      case 'tagUpdate':
        await _applyTag(body, create: kind == 'tagCreate');
      case 'tagDelete':
        final id = body['id'] as String;
        body['deleted_ids'] = [id, ...await _descendants(id)];
        await deleteTagsLocal([id]);
      case 'processed':
        break;
      default:
        throw StateError('未知画廊操作');
    }
    final seq = await db
        .into(db.galleryOperations)
        .insert(
          GalleryOperationsCompanion.insert(kind: kind, body: jsonEncode(body)),
        );
    return GalleryOperation(seq: seq, kind: kind, body: body);
  });

  Future<void> _applyPatch(Map<String, dynamic> body) async {
    final ids = (body['media_ids'] as List).cast<String>().toSet();
    if (ids.isEmpty) throw StateError('未选择媒体');
    if ((await getCachedMediaIds(ids)).length != ids.length) {
      throw StateError('媒体未缓存');
    }
    final expanded = {...ids};
    final leadId = body['group_id'] as String?;
    if (body.containsKey('is_deleted') || leadId != null) {
      for (final chunk in _chunks(ids)) {
        final marks = List.filled(chunk.length, '?').join(',');
        final rows = await db.customSelect("""
          WITH RECURSIVE members(id) AS (
            SELECT id FROM gallery_assets WHERE id IN ($marks)
            UNION SELECT m.id FROM gallery_assets m JOIN members g ON m.group_id = g.id
          ) SELECT id FROM members
          """, variables: chunk.map(Variable.new).toList()).get();
        expanded.addAll(rows.map((row) => row.read<String>('id')));
      }
    }
    if (leadId != null) {
      final lead = await getMediaAssetById(leadId);
      if (expanded.contains(leadId) ||
          lead == null ||
          lead.groupId != null ||
          lead.isDeleted) {
        throw StateError('主文件必须为未删除的独立媒体');
      }
    }
    final groupChanged = body.containsKey('group_id');
    final current = groupChanged ? await _currentLead() : null;
    body['affected_ids'] = expanded.toList();
    final propagated = GalleryAssetsCompanion(
      isDeleted: body.containsKey('is_deleted')
          ? Value(body['is_deleted'] == true)
          : const Value.absent(),
      groupId: leadId == null ? const Value.absent() : Value(leadId),
    );
    final annotations = GalleryAssetsCompanion(
      groupId: groupChanged && leadId == null
          ? const Value(null)
          : const Value.absent(),
      message: body.containsKey('message')
          ? Value(body['message'] as String?)
          : const Value.absent(),
      editParams: body.containsKey('edit_params')
          ? Value(body['edit_params'] as String?)
          : const Value.absent(),
    );
    await db.batch((batch) {
      for (final (affected, change) in [
        (expanded, propagated),
        (ids, annotations),
      ]) {
        if (change.toColumns(true).isEmpty) continue;
        for (final chunk in _chunks(affected)) {
          batch.update(
            db.galleryAssets,
            change,
            where: (row) => row.id.isIn(chunk),
          );
        }
      }
    });
    if (current != null) await _restoreLead(current);
  }

  Future<String?> _currentLead() async {
    final binding = await db.select(db.galleryPositions).getSingle();
    final row = await db
        .customSelect(
          'SELECT id FROM gallery_assets WHERE group_id IS NULL '
          'ORDER BY captured_at, id LIMIT 1 OFFSET ?',
          variables: [Variable(binding.currentIndex)],
        )
        .getSingleOrNull();
    return row?.read<String>('id');
  }

  Future<void> _restoreLead(String id) async {
    final asset = await getMediaAssetById(id);
    if (asset == null) return;
    final lead = asset.groupId == null
        ? asset
        : await getMediaAssetById(asset.groupId!);
    if (lead == null) return;
    final result = await db
        .customSelect(
          'SELECT COUNT(*) AS position FROM gallery_assets WHERE group_id IS NULL '
          'AND (captured_at, id) < (?, ?)',
          variables: [
            Variable(lead.capturedAt.microsecondsSinceEpoch),
            Variable(lead.id),
          ],
        )
        .getSingle();
    await setCurrentIndex(result.read<int>('position'));
  }

  Future<List<String>> _descendants(String parentId) async => [
    for (final row
        in await db
            .customSelect(
              """
      WITH RECURSIVE children(id) AS (
        SELECT id FROM gallery_tags WHERE parent_id = ?
        UNION SELECT t.id FROM gallery_tags t JOIN children ON t.parent_id = children.id
      ) SELECT id FROM children
      """,
              variables: [Variable(parentId)],
            )
            .get())
      row.read<String>('id'),
  ];

  Future<void> _applyTag(
    Map<String, dynamic> body, {
    required bool create,
  }) async {
    final tags = {for (final tag in await getAllTags()) tag.id: tag};
    final id = body['id'] as String;
    final current = tags[id];
    if (!create && current == null) throw StateError('标签不存在');
    if (create && current != null) throw StateError('标签已存在');
    final name = (body['name'] as String? ?? current?.name ?? '').trim();
    if (name.isEmpty) throw StateError('标签名不能为空');
    final parent = body.containsKey('parent_id')
        ? body['parent_id'] as String?
        : current?.parentId;
    if (parent != null && !tags.containsKey(parent)) throw StateError('父标签不存在');
    final seen = {id};
    for (var node = parent; node != null; node = tags[node]?.parentId) {
      if (!seen.add(node)) throw StateError('不能将标签移动到自身或子孙节点');
    }
    if (tags.values.any(
      (tag) => tag.id != id && tag.parentId == parent && tag.name == name,
    )) {
      throw StateError('同级已存在同名标签');
    }
    final now = DateTime.now();
    tags[id] = Tag(
      id: id,
      createdAt: current?.createdAt ?? now,
      updatedAt: now,
      name: name,
      parentId: parent,
      isFavorite: body['is_favorite'] as bool? ?? current?.isFavorite ?? false,
      mediaCount: current?.mediaCount ?? 0,
    );
    final descendants = await _descendants(id);
    body['affected_ids'] = [id, ...descendants];
    String pathFor(Tag tag) {
      final parts = <String>[];
      for (Tag? node = tag; node != null; node = tags[node.parentId]) {
        parts.add(node.name);
      }
      return parts.reversed.join('/');
    }

    await db.batch(
      (batch) => batch.insertAllOnConflictUpdate(db.galleryTags, [
        for (final affected in [id, ...descendants])
          _tagRow(tags[affected]!.copyWith(fullPath: pathFor(tags[affected]!))),
      ]),
    );
  }

  /// 服务端确认处理完成后，在一个提交里清除对应工作副本、已回传操作和浏览位置。
  Future<void> deleteProcessedData(
    List<String> mediaIds, {
    int? confirmedSequence,
  }) => db.transaction(() async {
    final ids = mediaIds.toSet();
    final completed = await operations();
    final request = completed
        .where((op) => op.kind == 'processed')
        .singleOrNull;
    final requested = (request?.body['media_ids'] as List? ?? []).toSet();
    if (completed.any((op) => op.kind != 'processed' && !op.synced) ||
        request?.seq != confirmedSequence ||
        requested.length != ids.length ||
        !ids.containsAll(requested)) {
      throw StateError('尚未收到完整的处理确认，本机修改已保留');
    }
    await db.batch((batch) {
      for (final op in completed) {
        final touched = {
          ...(op.body['media_ids'] as List? ?? []).cast<String>(),
          if (op.kind == 'patch')
            ...(op.body['affected_ids'] as List).cast<String>(),
          if (op.kind == 'tags') op.body['media_id'] as String,
        };
        final remaining = touched.difference(ids);
        if (op.kind == 'processed' || (op.synced && remaining.isEmpty)) {
          batch.deleteWhere(
            db.galleryOperations,
            (row) => row.seq.equals(op.seq),
          );
        } else if (op.synced &&
            remaining.length < touched.length &&
            op.kind == 'patch') {
          final body = {
            ...op.body,
            'media_ids': (op.body['media_ids'] as List)
                .where((id) => !ids.contains(id))
                .toList(),
            'affected_ids': remaining.toList(),
          };
          batch.update(
            db.galleryOperations,
            GalleryOperationsCompanion(body: Value(jsonEncode(body))),
            where: (row) => row.seq.equals(op.seq),
          );
        }
      }
      for (final chunk in _chunks(ids)) {
        batch.deleteWhere(db.galleryAssets, (row) => row.id.isIn(chunk));
      }
      batch.update(
        db.galleryPositions,
        const GalleryPositionsCompanion(currentIndex: Value(0)),
      );
    });
  });
}
