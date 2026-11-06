import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:torrid/features/others/gallery/services/gallery_api_service.dart';
import 'package:torrid/features/others/gallery/services/gallery_database_service.dart';

Future<void> verifyGalleryWrites(
  GalleryDatabaseService db,
  GalleryApiService api,
  List<GalleryOperation> operations,
) async {
  final fields = <String, Set<String>>{};
  final tagged = <String>{};
  final tagIds = <String>{};
  for (final operation in operations) {
    final body = operation.body;
    switch (operation.kind) {
      case 'patch':
        for (final id in (body['media_ids'] as List).cast<String>()) {
          fields
              .putIfAbsent(id, () => {})
              .addAll(
                body.keys.where(
                  (key) => key != 'media_ids' && key != 'affected_ids',
                ),
              );
        }
        for (final id in (body['affected_ids'] as List).cast<String>()) {
          final propagated = fields.putIfAbsent(id, () => {});
          if (body.containsKey('is_deleted')) propagated.add('is_deleted');
          if (body['group_id'] != null) propagated.add('group_id');
        }
      case 'tags':
        tagged.add(body['media_id'] as String);
      case 'tagCreate':
      case 'tagUpdate':
        tagIds.add(body['id'] as String);
        tagIds.addAll((body['affected_ids'] as List? ?? []).cast<String>());
      case 'tagDelete':
        tagIds.addAll((body['deleted_ids'] as List).cast<String>());
    }
  }

  Never mismatch(String id) => throw StateError('回传校验不一致（$id），本地操作已保留，请刷新或重试');
  final mediaIds = {...fields.keys, ...tagged}.toList();
  for (var offset = 0; offset < mediaIds.length; offset += 200) {
    final ids = mediaIds.skip(offset).take(200).toList();
    final result = await api.queryMedia(
      ids: ids,
      includeDeleted: true,
      limit: ids.length,
    );
    final remote = {
      for (final asset in result.mediaAssets) asset.id: asset.toJson(),
    };
    for (final id in ids) {
      final local = (await db.getMediaAssetById(id))?.toJson();
      if (local == null || remote[id] == null) mismatch(id);
      for (final field in fields[id] ?? <String>{}) {
        final expected = local[field];
        final actual = remote[id]![field];
        if (field == 'edit_params') {
          if (!_sameJson(expected as String?, actual as String?)) mismatch(id);
        } else if (field == 'message') {
          if ((expected ?? '') != (actual ?? '')) mismatch(id);
        } else if (expected != actual) {
          // 本机只保留已下载主文件的关联。
          if (field == 'group_id' &&
              expected == null &&
              actual is String &&
              (await db.getCachedMediaIds([actual])).isEmpty) {
            continue;
          }
          mismatch(id);
        }
      }
      if (tagged.contains(id)) {
        final expected = (await db.getTagIdsForMedia(id)).toSet();
        final actual = result.mediaTagLinks
            .where((link) => link.mediaId == id)
            .map((link) => link.tagId)
            .toSet();
        if (!setEquals(expected, actual)) mismatch(id);
      }
    }
  }
  if (tagIds.isNotEmpty) {
    final remote = {for (final tag in await api.fetchTags()) tag.id: tag};
    final local = {for (final tag in await db.getAllTags()) tag.id: tag};
    for (final id in tagIds) {
      final expected = local[id];
      final actual = remote[id];
      if (expected == null && actual == null) continue;
      if (expected == null ||
          actual == null ||
          expected.name != actual.name ||
          expected.parentId != actual.parentId ||
          expected.fullPath != actual.fullPath ||
          expected.isFavorite != actual.isFavorite) {
        mismatch(id);
      }
    }
  }
}

bool _sameJson(String? left, String? right) {
  if (left == right) return true;
  if (left == null || right == null) return false;
  Object? canonical(Object? value) {
    if (value is Map<String, dynamic>) {
      return {
        for (final key in value.keys.toList()..sort())
          key: canonical(value[key]),
      };
    }
    if (value is List) return value.map(canonical).toList();
    return value;
  }

  return jsonEncode(canonical(jsonDecode(left))) ==
      jsonEncode(canonical(jsonDecode(right)));
}
