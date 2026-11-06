import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/core/services/network/api_client.dart';
import 'package:torrid/core/utils/serialization.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/models/media_patch_intent.dart';
import 'package:torrid/features/others/gallery/models/media_tag_link.dart';
import 'package:torrid/features/others/gallery/models/tag.dart';
import 'package:torrid/features/others/gallery/services/gallery_database_service.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

part 'gallery_api_service.g.dart';

// 原文件执行编辑后 URL 随内容变化，避免图片缓存继续显示旧文件。
String galleryMediaUrl(
  String baseUrl,
  MediaAsset asset, {
  String type = 'file',
}) =>
    '$baseUrl/API/gallery/${asset.id}/$type?v=${Uri.encodeQueryComponent(asset.hash)}';

/// 媒体查询结果
typedef MediaQueryResult = ({
  List<MediaAsset> mediaAssets,
  List<MediaTagLink> mediaTagLinks,
  int total,
});

/// Gallery 服务端操作接口（服务端权威的唯一写入口）
///
/// 所有标签/标签关系/媒体标注的修改都通过这里写服务端, 本地表只做缓存.
/// 失败统一抛出 [ApiException]（含可读 message）.
@Riverpod(keepAlive: true)
GalleryApiService galleryApi(GalleryApiRef ref) {
  return GalleryApiService(ref.watch(apiClientManagerProvider));
}

class GalleryApiService {
  GalleryApiService(this._client);

  final ApiClient _client;

  Future<void> sendOperation(GalleryOperation operation) => _guard(() async {
    final body = Map<String, dynamic>.from(operation.body);
    final id = body.remove('id');
    body.remove('deleted_ids');
    body.remove('affected_ids');
    switch (operation.kind) {
      case 'patch':
      case 'processed':
        final response = await _client.patchJson(
          '/API/gallery/media',
          data: body,
        );
        final data = response.data as Map<String, dynamic>;
        if (operation.kind == 'processed' &&
            data['request_id'] != body['request_id']) {
          throw const FormatException('服务器不支持安全重试，请更新后端后重试回传');
        }
        final ids = _parseList(
          data['media_assets'],
          MediaAsset.fromJson,
        ).map((a) => a.id).toSet();
        if (!(body['media_ids'] as List).every(ids.contains)) {
          throw const FormatException('服务端未确认全部媒体');
        }
      case 'tags':
        final confirmed = await setMediaTags(
          body['media_id'] as String,
          (body['tag_ids'] as List).cast<String>(),
        );
        final expected = (body['tag_ids'] as List).toSet();
        if (confirmed.length != expected.length ||
            !confirmed.every(expected.contains)) {
          throw const FormatException('服务端未确认全部标签');
        }
      case 'tagCreate':
        final response = await _client.postJson(
          '/API/gallery/tags',
          data: {'id': id, ...body},
        );
        if (_tagOf(response.data)['id'] != id) {
          throw const FormatException('服务器不支持离线新建标签，请更新后端');
        }
      case 'tagUpdate':
        final response = await _client.putJson(
          '/API/gallery/tags/$id',
          data: body,
        );
        if (_tagOf(response.data)['id'] != id) {
          throw const FormatException('服务端未确认标签');
        }
      case 'tagDelete':
        try {
          await _client.delete('/API/gallery/tags/$id');
        } catch (error) {
          if (ApiClient.mapError(error).statusCode != 404) rethrow;
        }
      default:
        throw StateError('未知画廊操作');
    }
  });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e) {
      throw ApiClient.mapError(e);
    }
  }

  // 标签

  /// 获取完整标签树（含收藏标记与媒体数）
  Future<List<Tag>> fetchTags() {
    return _guard(() async {
      final resp = await _client.get('/API/gallery/tags');
      final data = resp.data as Map<String, dynamic>;
      return _parseList(data['tags'], Tag.fromJson);
    });
  }

  /// 新建标签
  Future<Tag> createTag({required String name, String? parentId}) {
    return _guard(() async {
      final resp = await _client.postJson(
        '/API/gallery/tags',
        data: {'name': name, if (parentId != null) 'parent_id': parentId},
      );
      return Tag.fromJson(_tagOf(resp.data));
    });
  }

  /// 更新标签（改名/移动/收藏）, 未提供的参数不修改
  Future<Tag> updateTag(
    String id, {
    String? name,
    String? parentId,
    bool moveToRoot = false,
    bool? isFavorite,
  }) {
    return _guard(() async {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (moveToRoot) {
        body['parent_id'] = null;
      } else if (parentId != null) {
        body['parent_id'] = parentId;
      }
      if (isFavorite != null) body['is_favorite'] = isFavorite;

      final resp = await _client.putJson('/API/gallery/tags/$id', data: body);
      return Tag.fromJson(_tagOf(resp.data));
    });
  }

  /// 删除标签, 返回被级联删除的全部标签 ID（含子孙）
  Future<List<String>> deleteTag(String id) {
    return _guard(() async {
      final resp = await _client.delete('/API/gallery/tags/$id');
      final data = resp.data as Map<String, dynamic>;
      return [
        for (final e in (data['deleted_ids'] as List? ?? const []))
          e.toString(),
      ];
    });
  }

  // 媒体查询与操作

  /// 按标签/类型/删除状态查询媒体及其标签关联
  ///
  /// [vlmTags] 为服务端 AI 标签（只读，与人工标签互不影响）；仅在需要时传入，
  /// 不传时服务端不会触及 AI 层。
  Future<MediaQueryResult> queryMedia({
    List<String> tagIds = const [],
    bool includeDescendants = false,
    bool untagged = false,
    bool includeDeleted = false,
    List<String> vlmTags = const [],
    List<String> ids = const [],
    String? mimeType,
    DateTime? capturedBefore,
    int limit = 60,
    int offset = 0,
    String? sortBy,
    String? sortOrder,
    CancelToken? cancelToken,
  }) {
    return _guard(() async {
      final params = <String, dynamic>{
        'limit': limit,
        'offset': offset,
        if (tagIds.isNotEmpty) 'tag_ids': tagIds.join(','),
        if (includeDescendants) 'include_descendants': true,
        if (untagged) 'untagged': true,
        if (includeDeleted) 'include_deleted': true,
        if (vlmTags.isNotEmpty) 'vlm_tags': vlmTags.join(','),
        if (ids.isNotEmpty) 'ids': ids.join(','),
        if (mimeType != null && mimeType.isNotEmpty) 'mime_type': mimeType,
        if (capturedBefore != null)
          'captured_before': dateToJson(capturedBefore),
        if (sortBy != null && sortBy.isNotEmpty) 'sort_by': sortBy,
        if (sortOrder != null && sortOrder.isNotEmpty) 'sort_order': sortOrder,
      };
      final resp = await _client.get(
        '/API/gallery/media',
        queryParams: params,
        cancelToken: cancelToken,
      );
      final data = resp.data as Map<String, dynamic>;
      return (
        mediaAssets: _parseList(data['media_assets'], MediaAsset.fromJson),
        mediaTagLinks: _parseList(
          data['media_tag_links'],
          MediaTagLink.fromJson,
        ),
        total: (data['total'] as num?)?.toInt() ?? 0,
      );
    });
  }

  Future<Set<String>> fetchAssignedTagIds(
    List<String> mediaIds, {
    CancelToken? cancelToken,
  }) async {
    final tags = <String>{};
    const batchSize = 100;
    for (var start = 0; start < mediaIds.length; start += batchSize) {
      final end = (start + batchSize).clamp(start, mediaIds.length);
      final page = await queryMedia(
        ids: mediaIds.sublist(start, end),
        includeDeleted: true,
        limit: end - start,
        cancelToken: cancelToken,
      );
      tags.addAll(page.mediaTagLinks.map((link) => link.tagId));
    }
    return tags;
  }

  /// 全量替换单个媒体的标签集合（幂等, 返回服务端确认的标签集合）
  Future<List<String>> setMediaTags(String mediaId, List<String> tagIds) {
    return _guard(() async {
      final resp = await _client.putJson(
        '/API/gallery/media/$mediaId/tags',
        data: {'tag_ids': tagIds},
      );
      final data = resp.data as Map<String, dynamic>;
      return [
        for (final e in (data['tag_ids'] as List? ?? const [])) e.toString(),
      ];
    });
  }

  /// 批量为多个媒体增删标签（幂等, 返回受影响行数）
  Future<int> batchMediaTags({
    required List<String> mediaIds,
    List<String> addTagIds = const [],
    List<String> removeTagIds = const [],
  }) {
    return _guard(() async {
      final resp = await _client.postJson(
        '/API/gallery/media/tags',
        data: {
          'media_ids': mediaIds,
          'add_tag_ids': addTagIds,
          'remove_tag_ids': removeTagIds,
        },
      );
      final data = resp.data as Map<String, dynamic>;
      return (data['affected'] as num?)?.toInt() ?? 0;
    });
  }

  /// 更新媒体标注, 返回服务端更新后的行
  Future<List<MediaAsset>> patchMedia({
    required List<String> mediaIds,
    required MediaPatchIntent intent,
  }) {
    return _guard(() async {
      final resp = await _client.patchJson(
        '/API/gallery/media',
        data: intent.toBody(mediaIds),
      );
      final data = resp.data as Map<String, dynamic>;
      return _parseList(data['media_assets'], MediaAsset.fromJson);
    });
  }

  // 解析辅助

  Map<String, dynamic> _tagOf(dynamic body) {
    final data = body as Map<String, dynamic>;
    return data['tag'] as Map<String, dynamic>;
  }

  List<T> _parseList<T>(
    dynamic raw,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (raw == null) return const [];
    if (raw is! List) throw const FormatException('服务端返回了无效的画廊列表');
    return raw
        .map((e) => fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
