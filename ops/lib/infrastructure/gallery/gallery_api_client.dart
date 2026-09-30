import 'dart:convert';
import 'dart:io';

import 'package:northstar/domain/gallery/models/gallery_media.dart';
import 'package:northstar/domain/ops/models/ops_settings.dart';
import 'package:northstar/infrastructure/api_http_helper.dart';

/// 统一画廊 API 异常（与 [OpsApiException] 同样的归一化策略）。
class GalleryApiException implements Exception {
  final String message;
  final int? statusCode;

  const GalleryApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// `/API/gallery/*` 客户端：媒体查询与标注写入（软删除）。
class GalleryApiClient {
  final ApiHttpClientHolder _http = ApiHttpClientHolder(
    connectTimeout: const Duration(seconds: 6),
  );

  static const Duration _timeout = Duration(seconds: 60);

  void dispose() => _http.dispose();

  /// 查询媒体。[onlyDeleted] 与 [includeDeleted] 互斥，前者优先。
  Future<GalleryMediaPage> fetchMedia(
    OpsSettings settings, {
    bool onlyDeleted = false,
    bool includeDeleted = false,
    int limit = 200,
    int offset = 0,
  }) async {
    final json = await _request(settings, 'GET', '/API/gallery/media', query: {
      if (onlyDeleted) 'only_deleted': 'true',
      if (includeDeleted) 'include_deleted': 'true',
      'sort_by': 'captured_at',
      'sort_order': 'desc',
      'limit': '$limit',
      'offset': '$offset',
    });
    final items = (json['media_assets'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => GalleryMedia.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return GalleryMediaPage(
      items: items,
      total: (json['total'] as num?)?.toInt() ?? items.length,
    );
  }

  /// 批量设置软删除标记；返回受影响的媒体。
  Future<int> setDeleted(
    OpsSettings settings,
    List<String> mediaIds, {
    required bool deleted,
  }) async {
    if (mediaIds.isEmpty) return 0;
    final json = await _request(settings, 'PATCH', '/API/gallery/media',
        body: {'media_ids': mediaIds, 'is_deleted': deleted});
    final updated = json['media_assets'] as List? ?? const [];
    return updated.length;
  }

  String thumbUrl(OpsSettings settings, String mediaId) =>
      buildApiUri(settings.apiBaseUrl, '/API/gallery/$mediaId/thumb').toString();

  // ---------- 内部 ----------

  Future<Map<String, dynamic>> _request(
    OpsSettings settings,
    String method,
    String endpoint, {
    Map<String, String>? query,
    Object? body,
  }) async {
    final uri = buildApiUri(settings.apiBaseUrl, endpoint).replace(
      queryParameters: (query == null || query.isEmpty) ? null : query,
    );
    final client = _http.clientFor(uri);
    final headers = buildApiHeaders(settings.apiKey);

    final request = await client.openUrl(method, uri);
    headers.forEach(request.headers.set);
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.add(utf8.encode(jsonEncode(body)));
    }

    final response = await request.close().timeout(_timeout);
    final responseBody = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = apiErrorDetailOf(tryDecodeJsonMap(responseBody));
      throw GalleryApiException(
        '接口请求失败: HTTP ${response.statusCode}$detail',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(responseBody);
    if (decoded is! Map) {
      throw const GalleryApiException('接口返回不是对象结构');
    }
    return Map<String, dynamic>.from(decoded);
  }
}
