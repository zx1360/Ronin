part of 'gallery_database_service.dart';

class GalleryOperation {
  final int seq;
  final String kind;
  final Map<String, dynamic> body;
  final bool synced;

  GalleryOperation.fromRow(Map<String, Object?> row)
    : seq = row['seq'] as int,
      kind = row['kind'] as String,
      body = jsonDecode(row['body'] as String) as Map<String, dynamic>,
      synced = row['synced'] == 1;
}

Future<void> _createOperations(DatabaseExecutor db) => db.execute('''
  CREATE TABLE IF NOT EXISTS gallery_operations (
    seq INTEGER PRIMARY KEY AUTOINCREMENT,
    kind TEXT NOT NULL,
    body TEXT NOT NULL,
    synced INTEGER NOT NULL DEFAULT 0
  )
''');

Future<bool> _hasOperations(DatabaseExecutor db) async => (await db.query(
  'gallery_operations',
  columns: ['seq'],
  limit: 1,
)).isNotEmpty;

extension GalleryOperationStore on GalleryDatabaseService {
  Future<List<GalleryOperation>> operations({
    bool pendingOnly = false,
    int? limit,
  }) async => (await (await database).query(
    'gallery_operations',
    orderBy: 'seq',
    limit: limit,
    where: pendingOnly ? "synced = 0 AND kind <> 'processed'" : null,
  )).map(GalleryOperation.fromRow).toList();

  Future<void> acknowledge(int seq) async => (await database).update(
    'gallery_operations',
    {'synced': 1},
    where: 'seq = ?',
    whereArgs: [seq],
  );

  /// 操作与工作副本同事务落盘，网络不参与本地提交。
  Future<void> recordOperation(String kind, Map<String, dynamic> data) async {
    final db = await database;
    await db.transaction((txn) async {
      final completing = await txn.query(
        'gallery_operations',
        columns: ['seq'],
        where: "kind = 'processed'",
        limit: 1,
      );
      if (completing.isNotEmpty) throw StateError('请先重试完成上次的标记已处理');
      final body = Map<String, dynamic>.from(data);
      switch (kind) {
        case 'patch':
          if (body.containsKey('mark_processed')) {
            throw StateError('请使用标记已处理入口');
          }
          await _applyPatch(txn, body);
        case 'tags':
          final mediaId = body['media_id'] as String;
          if ((await txn.query(
            'media_assets',
            where: 'id = ?',
            whereArgs: [mediaId],
          )).isEmpty) {
            throw StateError('媒体未缓存');
          }
          await txn.delete(
            'media_tag_links',
            where: 'media_id = ?',
            whereArgs: [mediaId],
          );
          for (final id in (body['tag_ids'] as List).toSet()) {
            await txn.insert('media_tag_links', {
              'media_id': mediaId,
              'tag_id': id,
            });
          }
        case 'tagCreate':
        case 'tagUpdate':
          await _applyTag(txn, body, create: kind == 'tagCreate');
        case 'tagDelete':
          final id = body['id'] as String;
          body['deleted_ids'] = [
            id,
            ...await _collectDescendantTagIds(txn, id),
          ];
          await txn.delete('tags', where: 'id = ?', whereArgs: [id]);
        case 'processed':
          break;
        default:
          throw StateError('未知画廊操作');
      }
      await txn.insert('gallery_operations', {
        'kind': kind,
        'body': jsonEncode(body),
      });
    });
  }

  Future<void> _applyPatch(Transaction txn, Map<String, dynamic> body) async {
    final ids = (body['media_ids'] as List).cast<String>().toSet();
    if (ids.isEmpty) throw StateError('未选择媒体');
    final expanded = <String>{};
    final cascade = body.containsKey('is_deleted') || body['group_id'] != null;
    for (final chunk in _mediaChunks(ids)) {
      final marks = List.filled(chunk.length, '?').join(',');
      final existing = await txn.rawQuery(
        'SELECT id FROM media_assets WHERE id IN ($marks)',
        chunk,
      );
      if (existing.length != chunk.length) throw StateError('媒体未缓存');
      if (cascade) {
        final rows = await txn.rawQuery('''
          WITH RECURSIVE members(id) AS (
            SELECT id FROM media_assets WHERE id IN ($marks)
            UNION SELECT m.id FROM media_assets m JOIN members g ON m.group_id = g.id
          ) SELECT id FROM members
        ''', chunk);
        expanded.addAll(rows.map((row) => row['id'] as String));
      } else {
        expanded.addAll(chunk);
      }
    }
    final lead = body['group_id'];
    if (lead != null) {
      final rows = await txn.query(
        'media_assets',
        columns: ['group_id', 'is_deleted'],
        where: 'id = ?',
        whereArgs: [lead],
      );
      if (expanded.contains(lead) ||
          rows.isEmpty ||
          rows.single['group_id'] != null ||
          rows.single['is_deleted'] == 1) {
        throw StateError('主文件必须为未删除的独立媒体');
      }
    }
    body['affected_ids'] = expanded.toList();
    final propagated = <String, Object?>{
      if (body.containsKey('is_deleted'))
        'is_deleted': body['is_deleted'] == true ? 1 : 0,
      if (lead != null) 'group_id': lead,
    };
    final annotations = <String, Object?>{
      if (body.containsKey('group_id') && lead == null) 'group_id': null,
      if (body.containsKey('message')) 'message': body['message'],
      if (body.containsKey('edit_params')) 'edit_params': body['edit_params'],
    };
    for (final change in [(expanded, propagated), (ids, annotations)]) {
      if (change.$2.isEmpty) continue;
      for (final chunk in _mediaChunks(change.$1)) {
        await txn.update(
          'media_assets',
          change.$2,
          where: 'id IN (${List.filled(chunk.length, '?').join(',')})',
          whereArgs: chunk,
        );
      }
    }
  }

  Future<void> _applyTag(
    Transaction txn,
    Map<String, dynamic> body, {
    required bool create,
  }) async {
    final rows = await txn.query('tags');
    final tags = {
      for (final row in rows) row['id'] as String: Tag.fromDbMap(row),
    };
    final id = body['id'] as String;
    final current = tags[id];
    if (!create && current == null) throw StateError('标签不存在');
    body['affected_ids'] = [id, ...await _collectDescendantTagIds(txn, id)];
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
    for (final tag in GalleryDatabaseService.sortTagsByHierarchy(
      tags.values.toList(),
    )) {
      final path = tag.parentId == null
          ? tag.name
          : '${tags[tag.parentId]!.fullPath}/${tag.name}';
      final updated = tag.copyWith(fullPath: path);
      tags[tag.id] = updated;
      await _writeTag(txn, updated);
    }
  }
}

Iterable<List<String>> _mediaChunks(Iterable<String> ids) sync* {
  final list = ids.toList();
  for (var offset = 0; offset < list.length; offset += 400) {
    yield list.sublist(offset, (offset + 400).clamp(0, list.length));
  }
}
