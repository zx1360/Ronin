part of 'gallery_database_service.dart';

class GalleryOperation {
  final int seq;
  final String server;
  final String kind;
  final Map<String, dynamic> body;
  final bool synced;

  GalleryOperation.fromRow(Map<String, Object?> row)
    : seq = row['seq'] as int,
      server = row['server'] as String,
      kind = row['kind'] as String,
      body = jsonDecode(row['body'] as String) as Map<String, dynamic>,
      synced = row['synced'] == 1;
}

Future<void> _createOperations(DatabaseExecutor db) => db.execute('''
  CREATE TABLE IF NOT EXISTS gallery_operations (
    seq INTEGER PRIMARY KEY AUTOINCREMENT,
    server TEXT NOT NULL,
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
  Future<void> recordOperation(
    String server,
    String kind,
    Map<String, dynamic> data,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      final previous = await txn.query('gallery_operations');
      if (previous.any((row) => row['server'] != server)) {
        throw StateError('请切回原画廊服务器完成回传');
      }
      if (previous.any((row) => row['kind'] == 'processed')) {
        throw StateError('请先重试完成上次的标记已处理');
      }
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
        'server': server,
        'kind': kind,
        'body': jsonEncode(body),
      });
    });
  }

  Future<void> _applyPatch(Transaction txn, Map<String, dynamic> body) async {
    final ids = (body['media_ids'] as List).cast<String>().toSet();
    final rows = await txn.query('media_assets');
    final assets = {for (final row in rows) row['id'] as String: row};
    if (!ids.every(assets.containsKey)) throw StateError('媒体未缓存');
    final expanded = {...ids};
    if (body.containsKey('is_deleted') || body['group_id'] != null) {
      var changed = true;
      while (changed) {
        changed = false;
        for (final row in rows) {
          if (expanded.contains(row['group_id']) &&
              expanded.add(row['id'] as String)) {
            changed = true;
          }
        }
      }
    }
    final lead = body['group_id'];
    if (lead != null &&
        (expanded.contains(lead) ||
            assets[lead] == null ||
            assets[lead]!['group_id'] != null ||
            assets[lead]!['is_deleted'] == 1)) {
      throw StateError('主文件必须为未删除的独立媒体');
    }
    // 固定受影响成员，重放时不依赖之后的本地分组状态。
    body['affected_ids'] = expanded.toList();
    for (final id in expanded) {
      final values = <String, Object?>{};
      if (body.containsKey('is_deleted')) {
        values['is_deleted'] = body['is_deleted'] == true ? 1 : 0;
      }
      if (body.containsKey('group_id')) values['group_id'] = lead;
      if (ids.contains(id)) {
        if (body.containsKey('message')) values['message'] = body['message'];
        if (body.containsKey('edit_params')) {
          values['edit_params'] = body['edit_params'];
        }
      }
      if (values.isNotEmpty) {
        await txn.update(
          'media_assets',
          values,
          where: 'id = ?',
          whereArgs: [id],
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
