import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:torrid/core/services/debug/logging_service.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/models/tag.dart';
import 'package:torrid/features/others/gallery/models/media_tag_link.dart';

/// Gallery 模块数据库服务 - 单例模式
/// 管理 media_assets, tags, media_tag_links 三张表
class GalleryDatabaseService {
  static final GalleryDatabaseService _instance =
      GalleryDatabaseService._internal();
  factory GalleryDatabaseService() => _instance;
  GalleryDatabaseService._internal();

  static Database? _database;
  static const String _dbName = 'gallery.db';
  static const int _dbVersion = 1;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
      onOpen: _ensureTablesExist,
    );
  }

  /// 启用外键约束
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// 确保表存在 (防止数据库文件存在但表不存在的情况)
  Future<void> _ensureTablesExist(Database db) async {
    // 检查 media_assets 表是否存在
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='media_assets'"
    );
    if (tables.isEmpty) {
      AppLogger().info('Gallery 表不存在，重新创建...');
      await _onCreate(db, _dbVersion);
    }
  }

  /// 数据库升级
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    AppLogger().info('Gallery 数据库升级: $oldVersion -> $newVersion');
    // 未来版本升级逻辑
  }

  /// 创建表结构 - 与服务端 PostgreSQL 保持一致
  Future<void> _onCreate(Database db, int version) async {
    // 媒体文件表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS media_assets (
        id TEXT PRIMARY KEY,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        captured_at TEXT NOT NULL,
        file_path TEXT NOT NULL,
        thumb_path TEXT,
        preview_path TEXT,
        hash TEXT NOT NULL UNIQUE,
        size_bytes INTEGER NOT NULL DEFAULT 0,
        mime_type TEXT,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        sync_count INTEGER NOT NULL DEFAULT 0,
        group_id TEXT DEFAULT NULL,
        message TEXT DEFAULT NULL,
        FOREIGN KEY (group_id) REFERENCES media_assets(id) ON DELETE SET NULL
      )
    ''');

    // 标签表 - 树状结构
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tags (
        id TEXT PRIMARY KEY,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        name TEXT NOT NULL,
        parent_id TEXT,
        full_path TEXT,
        FOREIGN KEY (parent_id) REFERENCES tags(id) ON DELETE CASCADE,
        UNIQUE (name, parent_id)
      )
    ''');

    // 媒体-标签关联表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS media_tag_links (
        media_id TEXT NOT NULL,
        tag_id TEXT NOT NULL,
        PRIMARY KEY (tag_id, media_id),
        FOREIGN KEY (media_id) REFERENCES media_assets(id) ON DELETE CASCADE,
        FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
      )
    ''');

    // 创建索引
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_media_assets_captured_at ON media_assets(captured_at)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_media_assets_group_id ON media_assets(group_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_tags_parent_id ON tags(parent_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_media_tag_links_media_id ON media_tag_links(media_id)');

    AppLogger().info('Gallery 数据库初始化完成');
  }

  // ============ MediaAsset CRUD ============

  /// 插入或更新媒体文件记录 (批量)
  Future<void> upsertMediaAssets(List<MediaAsset> assets) async {
    final db = await database;
    final batch = db.batch();

    for (final asset in assets) {
      batch.insert(
        'media_assets',
        asset.toDbMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// 获取所有媒体文件 (按 captured_at 升序, 排除已绑定的非主文件)
  Future<List<MediaAsset>> getMediaAssets({bool includeGroupMembers = false}) async {
    final db = await database;
    final String where = includeGroupMembers ? '' : 'WHERE group_id IS NULL';
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT * FROM media_assets $where ORDER BY captured_at ASC
    ''');
    return maps.map((m) => MediaAsset.fromDbMap(m)).toList();
  }

  /// 获取媒体文件总数
  Future<int> getMediaAssetCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM media_assets');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 根据 ID 获取媒体文件
  Future<MediaAsset?> getMediaAssetById(String id) async {
    final db = await database;
    final maps = await db.query('media_assets', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return MediaAsset.fromDbMap(maps.first);
  }

  /// 更新媒体文件
  Future<int> updateMediaAsset(MediaAsset asset) async {
    final db = await database;
    return await db.update(
      'media_assets',
      asset.toDbMap(),
      where: 'id = ?',
      whereArgs: [asset.id],
    );
  }

  /// 标记媒体文件为已删除 (软删除)
  Future<void> markMediaAssetDeleted(String id, {bool deleted = true}) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      // 如果是主文件，同时标记所有组成员
      await txn.rawUpdate('''
        UPDATE media_assets 
        SET is_deleted = ?, updated_at = ? 
        WHERE id = ? OR group_id = ?
      ''', [deleted ? 1 : 0, now, id, id]);
    });
  }

  /// 设置媒体文件的 group_id (捆绑)
  Future<void> setMediaGroupId(List<String> memberIds, String? leadId) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    final batch = db.batch();
    for (final memberId in memberIds) {
      batch.update(
        'media_assets',
        {'group_id': leadId, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [memberId],
      );
    }
    await batch.commit(noResult: true);
  }

  /// 获取某主文件的所有组成员
  Future<List<MediaAsset>> getGroupMembers(String leadId) async {
    final db = await database;
    final maps = await db.query(
      'media_assets',
      where: 'group_id = ?',
      whereArgs: [leadId],
    );
    return maps.map((m) => MediaAsset.fromDbMap(m)).toList();
  }

  /// 删除媒体文件记录 (物理删除)
  Future<void> deleteMediaAssets(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.delete(
      'media_assets',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }

  // ============ Tag CRUD ============

  /// 插入或更新标签 (批量) - 全量替换
  Future<void> replaceAllTags(List<Tag> tags) async {
    final db = await database;
    await db.transaction((txn) async {
      // 先删除所有标签
      await txn.delete('tags');
      // 再批量插入
      for (final tag in tags) {
        await txn.insert('tags', tag.toDbMap());
      }
    });
  }

  /// 插入或更新标签 (单个)
  Future<void> upsertTag(Tag tag) async {
    final db = await database;
    await db.insert(
      'tags',
      tag.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 获取所有标签
  Future<List<Tag>> getAllTags() async {
    final db = await database;
    final maps = await db.query('tags', orderBy: 'full_path ASC');
    return maps.map((m) => Tag.fromDbMap(m)).toList();
  }

  /// 获取根标签
  Future<List<Tag>> getRootTags() async {
    final db = await database;
    final maps = await db.query(
      'tags',
      where: 'parent_id IS NULL',
      orderBy: 'name ASC',
    );
    return maps.map((m) => Tag.fromDbMap(m)).toList();
  }

  /// 获取子标签
  Future<List<Tag>> getChildTags(String parentId) async {
    final db = await database;
    final maps = await db.query(
      'tags',
      where: 'parent_id = ?',
      whereArgs: [parentId],
      orderBy: 'name ASC',
    );
    return maps.map((m) => Tag.fromDbMap(m)).toList();
  }

  /// 获取标签总数
  Future<int> getTagCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM tags');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 删除标签 (级联删除子标签和关联)
  Future<void> deleteTag(String tagId) async {
    final db = await database;
    await db.delete('tags', where: 'id = ?', whereArgs: [tagId]);
  }

  /// 更新标签 (含 full_path 级联更新)
  Future<void> updateTagWithCascade(Tag tag) async {
    final db = await database;

    await db.transaction((txn) async {
      // 更新当前标签
      await txn.update('tags', tag.toDbMap(), where: 'id = ?', whereArgs: [tag.id]);

      // 级联更新所有子标签的 full_path
      await _cascadeUpdateFullPath(txn, tag.id, tag.fullPath ?? tag.name);
    });
  }

  /// 递归更新子标签的 full_path
  Future<void> _cascadeUpdateFullPath(
      Transaction txn, String parentId, String parentPath) async {
    final children = await txn.query(
      'tags',
      where: 'parent_id = ?',
      whereArgs: [parentId],
    );

    for (final child in children) {
      final childId = child['id'] as String;
      final childName = child['name'] as String;
      final newFullPath = '$parentPath/$childName';
      final now = DateTime.now().toIso8601String();

      await txn.update(
        'tags',
        {'full_path': newFullPath, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [childId],
      );

      // 递归更新
      await _cascadeUpdateFullPath(txn, childId, newFullPath);
    }
  }

  // ============ MediaTagLink CRUD ============

  /// 插入媒体-标签关联 (批量)
  Future<void> upsertMediaTagLinks(List<MediaTagLink> links) async {
    if (links.isEmpty) return;
    final db = await database;
    final batch = db.batch();

    for (final link in links) {
      batch.insert(
        'media_tag_links',
        link.toDbMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// 获取媒体文件关联的所有标签 ID
  Future<List<String>> getTagIdsForMedia(String mediaId) async {
    final db = await database;
    final maps = await db.query(
      'media_tag_links',
      columns: ['tag_id'],
      where: 'media_id = ?',
      whereArgs: [mediaId],
    );
    return maps.map((m) => m['tag_id'] as String).toList();
  }

  /// 获取媒体文件关联的所有标签
  Future<List<Tag>> getTagsForMedia(String mediaId) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT t.* FROM tags t
      INNER JOIN media_tag_links mtl ON t.id = mtl.tag_id
      WHERE mtl.media_id = ?
      ORDER BY t.full_path ASC
    ''', [mediaId]);
    return maps.map((m) => Tag.fromDbMap(m)).toList();
  }

  /// 设置媒体文件的标签 (全量替换)
  Future<void> setTagsForMedia(String mediaId, List<String> tagIds) async {
    final db = await database;
    await db.transaction((txn) async {
      // 删除旧关联
      await txn.delete('media_tag_links', where: 'media_id = ?', whereArgs: [mediaId]);
      // 插入新关联
      for (final tagId in tagIds) {
        await txn.insert('media_tag_links', {
          'media_id': mediaId,
          'tag_id': tagId,
        });
      }
    });
  }

  /// 获取所有媒体-标签关联
  Future<List<MediaTagLink>> getAllMediaTagLinks() async {
    final db = await database;
    final maps = await db.query('media_tag_links');
    return maps.map((m) => MediaTagLink.fromDbMap(m)).toList();
  }

  /// 获取关联记录总数
  Future<int> getMediaTagLinkCount() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as count FROM media_tag_links');
    return Sqflite.firstIntValue(result) ?? 0;
  }
  
  /// 获取需要上传的 media_assets 记录数 (sync_count <= modifiedCount)
  Future<int> getModifiedMediaAssetCount(int modifiedCount) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM media_assets WHERE sync_count <= ?',
      [modifiedCount],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
  
  /// 获取需要上传的 media_assets 的 ID 列表
  Future<List<String>> getModifiedMediaAssetIds(int modifiedCount) async {
    final db = await database;
    final maps = await db.rawQuery(
      'SELECT id FROM media_assets WHERE sync_count <= ?',
      [modifiedCount],
    );
    return maps.map((m) => m['id'] as String).toList();
  }
  
  /// 获取与指定 media_ids 关联的 media_tag_links 记录数
  Future<int> getMediaTagLinkCountForMediaIds(List<String> mediaIds) async {
    if (mediaIds.isEmpty) return 0;
    final db = await database;
    final placeholders = List.filled(mediaIds.length, '?').join(',');
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM media_tag_links WHERE media_id IN ($placeholders)',
      mediaIds,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 删除指定媒体的所有标签关联
  Future<void> deleteMediaTagLinks(List<String> mediaIds) async {
    if (mediaIds.isEmpty) return;
    final db = await database;
    final placeholders = List.filled(mediaIds.length, '?').join(',');
    await db.delete(
      'media_tag_links',
      where: 'media_id IN ($placeholders)',
      whereArgs: mediaIds,
    );
  }

  // ============ 批量操作 / 同步相关 ============

  /// 清空所有表数据
  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('media_tag_links');
      await txn.delete('tags');
      await txn.delete('media_assets');
    });
    AppLogger().info('Gallery 数据库已清空');
  }

  /// 获取待上传的数据包
  Future<({List<MediaAsset> assets, List<Tag> tags, List<MediaTagLink> links})>
      getDataForUpload() async {
    final assets = await getMediaAssets(includeGroupMembers: true);
    final tags = await getAllTags();
    final links = await getAllMediaTagLinks();
    return (assets: assets, tags: tags, links: links);
  }

  /// 关闭数据库
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
