import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/core/api/generated/api_contract.dart' show ApiPath;
import 'package:torrid/core/constants/paging.dart';
import 'package:torrid/core/services/network/api_client.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/models/media_patch_intent.dart';
import 'package:torrid/features/others/gallery/models/media_tag_link.dart';
import 'package:torrid/features/others/gallery/models/tag.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

part 'gallery_api_service.g.dart';

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
      final resp = await _client.get(ApiPath.galleryTags);
      final data = resp.data as Map<String, dynamic>;
      return _parseList(data['tags'], Tag.fromJson);
    });
  }

  /// 新建标签
  Future<Tag> createTag({required String name, String? parentId}) {
    return _guard(() async {
      final resp = await _client.postJson(ApiPath.galleryTags, data: {
        'name': name,
        if (parentId != null) 'parent_id': parentId,
      });
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

      final resp = await _client.putJson(ApiPath.galleryTagsIdPath(id), data: body);
      return Tag.fromJson(_tagOf(resp.data));
    });
  }

  /// 删除标签, 返回被级联删除的全部标签 ID（含子孙）
  Future<List<String>> deleteTag(String id) {
    return _guard(() async {
      final resp = await _client.delete(ApiPath.galleryTagsIdPath(id));
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
    int limit = mediaPageSize,
    int offset = 0,
    String? sortBy,
    String? sortOrder,
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
        if (sortBy != null && sortBy.isNotEmpty) 'sort_by': sortBy,
        if (sortOrder != null && sortOrder.isNotEmpty) 'sort_order': sortOrder,
      };
      final resp = await _client.get(ApiPath.galleryMedia, queryParams: params);
      final data = resp.data as Map<String, dynamic>;
      return (
        mediaAssets: _parseList(data['media_assets'], MediaAsset.fromJson),
        mediaTagLinks:
            _parseList(data['media_tag_links'], MediaTagLink.fromJson),
        total: (data['total'] as num?)?.toInt() ?? 0,
      );
    });
  }

  /// 全量替换单个媒体的标签集合（幂等, 返回服务端确认的标签集合）
  Future<List<String>> setMediaTags(String mediaId, List<String> tagIds) {
    return _guard(() async {
      final resp = await _client.putJson(
        ApiPath.galleryMediaIdTagsPath(mediaId),
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
      final resp = await _client.postJson(ApiPath.galleryMediaTags, data: {
        'media_ids': mediaIds,
        'add_tag_ids': addTagIds,
        'remove_tag_ids': removeTagIds,
      });
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
        ApiPath.galleryMediaPatch,
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
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is Map<String, dynamic>) fromJson(e),
    ];
  }
}
