import 'dart:convert';
import 'dart:io';

import 'package:northstar/domain/ai/models/ai_models.dart';
import 'package:northstar/domain/gallery/models/gallery_media.dart';
import 'package:northstar/domain/ops/models/ops_settings.dart';
import 'package:northstar/infrastructure/api_http_helper.dart';

/// 统一 AI API 异常（与 [OpsApiException] 同样的归一化策略）。
class AiApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? body;

  const AiApiException(this.message, {this.statusCode, this.body});

  @override
  String toString() => message;
}

/// `/API/ai/*` 客户端：AI 运维、检索与人物分组。
class AiApiClient {
  final ApiHttpClientHolder _http = ApiHttpClientHolder(
    connectTimeout: const Duration(seconds: 6),
  );

  /// 默认请求超时；重新聚类等长任务单独放宽。
  static const Duration _defaultTimeout = Duration(seconds: 30);
  static const Duration _longTimeout = Duration(seconds: 30 * 60);

  void dispose() => _http.dispose();

  // ---------- 运维 ----------

  Future<AiStatus> fetchStatus(OpsSettings settings) async {
    final json = await _request(settings, 'GET', '/API/ai/status');
    return AiStatus.fromJson(json);
  }

  Future<({List<AiJob> jobs, int total})> fetchJobs(
    OpsSettings settings, {
    String? capability,
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    final json = await _request(settings, 'GET', '/API/ai/jobs', query: {
      if (capability != null && capability.isNotEmpty) 'capability': capability,
      if (status != null && status.isNotEmpty) 'status': status,
      'limit': '$limit',
      'offset': '$offset',
    });
    final jobs = (json['jobs'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => AiJob.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return (jobs: jobs, total: (json['total'] as num?)?.toInt() ?? jobs.length);
  }

  /// 入队：mediaIds 为空时按 scope=missing 对全库缺该产物的媒体补处理。
  Future<Map<String, dynamic>> enqueue(
    OpsSettings settings, {
    required List<String> capabilities,
    List<String> mediaIds = const [],
    String scope = '',
  }) {
    return _request(settings, 'POST', '/API/ai/enqueue', body: {
      'capabilities': capabilities,
      if (mediaIds.isNotEmpty) 'media_ids': mediaIds,
      if (scope.isNotEmpty) 'scope': scope,
    });
  }

  Future<int> retry(
    OpsSettings settings, {
    String? capability,
    List<String> mediaIds = const [],
  }) async {
    final json = await _request(settings, 'POST', '/API/ai/retry', body: {
      if (capability != null && capability.isNotEmpty) 'capability': capability,
      if (mediaIds.isNotEmpty) 'media_ids': mediaIds,
    });
    return (json['retried'] as num?)?.toInt() ?? 0;
  }

  /// 暂停处理：中断当前批次并停止认领新任务，直到 [resume]。
  Future<bool> pause(OpsSettings settings) async {
    final json = await _request(settings, 'POST', '/API/ai/cancel');
    return json['paused'] == true;
  }

  /// 继续处理。
  Future<void> resume(OpsSettings settings) =>
      _request(settings, 'POST', '/API/ai/resume');

  Future<void> startModel(OpsSettings settings, String capability) =>
      _request(settings, 'POST', '/API/ai/process/$capability/start',
          timeout: _longTimeout);

  Future<void> stopModel(OpsSettings settings, String capability) =>
      _request(settings, 'POST', '/API/ai/process/$capability/stop');

  Future<int> rebuildIndex(OpsSettings settings) async {
    final json = await _request(settings, 'POST', '/API/ai/index/rebuild',
        timeout: _longTimeout);
    return (json['vectors'] as num?)?.toInt() ?? 0;
  }

  Future<List<String>> fetchAutoCapabilities(OpsSettings settings) async {
    final json = await _request(settings, 'GET', '/API/ai/settings');
    return (json['auto_capabilities'] as List? ?? const [])
        .map((e) => e.toString())
        .toList();
  }

  Future<List<String>> updateAutoCapabilities(
    OpsSettings settings,
    List<String> capabilities,
  ) async {
    final json = await _request(settings, 'PUT', '/API/ai/settings',
        body: {'auto_capabilities': capabilities});
    return (json['auto_capabilities'] as List? ?? const [])
        .map((e) => e.toString())
        .toList();
  }

  /// 切换 VLM 自动标注使用的模型（传空串恢复 .env 默认）。
  Future<String> updateVlmModel(OpsSettings settings, String model) async {
    final json = await _request(settings, 'PUT', '/API/ai/settings',
        body: {'vlm_model': model});
    return (json['vlm_model'] ?? '').toString();
  }

  // ---------- 检索 ----------

  Future<AiSearchResult> search(
    OpsSettings settings, {
    String query = '',
    String mode = 'auto',
    List<String> tagIds = const [],
    List<String> personIds = const [],
    String mimeType = '',
    int limit = 60,
    int offset = 0,
  }) async {
    final json = await _request(settings, 'GET', '/API/ai/search', query: {
      if (query.trim().isNotEmpty) 'q': query.trim(),
      'mode': mode,
      if (tagIds.isNotEmpty) 'tag_ids': tagIds.join(','),
      if (personIds.isNotEmpty) 'person_ids': personIds.join(','),
      if (mimeType.isNotEmpty) 'mime_type': mimeType,
      'limit': '$limit',
      'offset': '$offset',
    }, timeout: _longTimeout);
    return AiSearchResult.fromJson(json);
  }

  Future<AiSearchResult> similar(
    OpsSettings settings,
    String mediaId, {
    int limit = 40,
  }) async {
    final json = await _request(settings, 'GET', '/API/ai/similar/$mediaId',
        query: {'limit': '$limit'}, timeout: _longTimeout);
    return AiSearchResult.fromJson(json);
  }

  /// 近重复分组（pHash）；[ignoredTotal] 为已标记「非重复」的数量。
  Future<({List<AiDuplicateGroup> groups, int ignoredTotal})> fetchDuplicates(
    OpsSettings settings, {
    int maxDistance = 4,
  }) async {
    final json = await _request(settings, 'GET', '/API/ai/duplicates',
        query: {'max_distance': '$maxDistance'}, timeout: _longTimeout);
    final groups = (json['groups'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => AiDuplicateGroup.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return (
      groups: groups,
      ignoredTotal: (json['ignored_total'] as num?)?.toInt() ?? 0,
    );
  }

  /// 把媒体标记为「非重复」：之后不再参与近重复分组。
  Future<int> ignoreDuplicates(
    OpsSettings settings,
    List<String> mediaIds,
  ) async {
    final json = await _request(settings, 'POST', '/API/ai/duplicates/ignore',
        body: {'media_ids': mediaIds});
    return (json['total'] as num?)?.toInt() ?? 0;
  }

  /// 取消「非重复」标记。
  Future<int> unignoreDuplicates(
    OpsSettings settings,
    List<String> mediaIds,
  ) async {
    final json = await _request(settings, 'POST', '/API/ai/duplicates/unignore',
        body: {'media_ids': mediaIds});
    return (json['total'] as num?)?.toInt() ?? 0;
  }

  /// 已标记「非重复」的媒体（恢复入口用）。
  Future<List<GalleryMedia>> fetchIgnoredDuplicates(
    OpsSettings settings,
  ) async {
    final json = await _request(settings, 'GET', '/API/ai/duplicates/ignored',
        timeout: _longTimeout);
    return (json['media_assets'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => GalleryMedia.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // ---------- 人物分组 ----------

  Future<List<AiPerson>> fetchPersons(OpsSettings settings) async {
    final json = await _request(settings, 'GET', '/API/ai/persons');
    return (json['persons'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => AiPerson.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> renamePerson(
    OpsSettings settings,
    String personId, {
    required String name,
  }) =>
      _request(settings, 'PATCH', '/API/ai/persons/$personId',
          body: {'name': name});

  Future<void> deletePerson(OpsSettings settings, String personId) =>
      _request(settings, 'DELETE', '/API/ai/persons/$personId');

  Future<int> mergePersons(
    OpsSettings settings, {
    required List<String> sourceIds,
    required String targetId,
  }) async {
    final json = await _request(settings, 'POST', '/API/ai/persons/merge',
        body: {'source_ids': sourceIds, 'target_id': targetId});
    return (json['moved_faces'] as num?)?.toInt() ?? 0;
  }

  /// 重新聚类；reset=true 会清空现有人物分组（丢失人工命名），需二次确认。
  Future<Map<String, dynamic>> recluster(
    OpsSettings settings, {
    bool reset = false,
  }) {
    return _request(settings, 'POST', '/API/ai/recluster',
        body: {'reset': reset}, timeout: _longTimeout);
  }

  /// 媒体缩略图地址（复用 gallery 文件流接口）。
  String thumbUrl(OpsSettings settings, String mediaId) =>
      buildApiUri(settings.apiBaseUrl, '/API/gallery/$mediaId/thumb').toString();

  /// 画廊媒体接口前缀（自行拼接 `/{id}/thumb`、`/{id}/file`）。
  String galleryBaseUrl(OpsSettings settings) =>
      buildApiUri(settings.apiBaseUrl, '/API/gallery').toString();

  // ---------- 内部 ----------

  Future<Map<String, dynamic>> _request(
    OpsSettings settings,
    String method,
    String endpoint, {
    Map<String, String>? query,
    Object? body,
    Duration timeout = _defaultTimeout,
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

    final response = await request.close().timeout(timeout);
    final responseBody = await response.transform(utf8.decoder).join();
    _throwIfNotOk(response.statusCode, body: responseBody);

    final decoded = jsonDecode(responseBody);
    if (decoded is! Map) {
      throw const AiApiException('接口返回不是对象结构');
    }
    return Map<String, dynamic>.from(decoded);
  }

  void _throwIfNotOk(int statusCode, {String? body}) {
    if (statusCode >= 200 && statusCode < 300) return;
    final detail = apiErrorDetailOf(tryDecodeJsonMap(body ?? ''));
    throw AiApiException(
      '接口请求失败: HTTP $statusCode$detail',
      statusCode: statusCode,
      body: body,
    );
  }
}
