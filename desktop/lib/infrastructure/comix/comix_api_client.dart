import 'dart:convert';
import 'dart:io';

import 'package:northstar/domain/comix/models/comix_models.dart';
import 'package:northstar/domain/ops/models/ops_settings.dart';
import 'package:northstar/services/cert_trust.dart';

/// 统一 comix API 异常（HTTP 级或业务 ok=false）。
class ComixApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? payload;

  const ComixApiException(this.message, {this.statusCode, this.payload});

  @override
  String toString() => message;
}

/// Monarch `/API/comix/*` 的 HTTP 客户端。
///
/// 复用 OpsSettings（apiBaseUrl + apiKey）与 CertTrust（自签证书），
/// 与 OpsApiClient 同一套连接模式；仅 comix 接口专用。
class ComixApiClient {
  HttpClient? _client;
  Uri? _lastBaseUri;

  HttpClient _getClient(Uri uri) {
    final isHttps = uri.scheme.toLowerCase() == 'https';
    if (_client != null && _lastBaseUri?.origin == uri.origin) {
      return _client!;
    }
    _client?.close(force: true);
    _client = isHttps
        ? CertTrust.createSecureClient()
        : (HttpClient()..connectionTimeout = const Duration(seconds: 8));
    _lastBaseUri = uri;
    return _client!;
  }

  void dispose() {
    _client?.close(force: true);
    _client = null;
    _lastBaseUri = null;
  }

  // --- 同步只读接口 ---

  Future<ComixConfig> fetchConfig(OpsSettings settings) async {
    final json = await _getJson(settings, '/API/comix/config');
    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      throw const ComixApiException('comix 配置接口返回结构异常');
    }
    return ComixConfig.fromJson(data);
  }

  Future<List<ComixSite>> fetchSites(OpsSettings settings) async {
    final json = await _getJson(settings, '/API/comix/sites');
    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      throw const ComixApiException('sites 接口返回结构异常');
    }
    final list = data['sites'];
    if (list is! List) return const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(ComixSite.fromJson)
        .toList();
  }

  Future<List<ComixComic>> fetchComics(OpsSettings settings) async {
    final json = await _getJson(settings, '/API/comix/list');
    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      throw const ComixApiException('list 接口返回结构异常');
    }
    final list = data['comics'];
    if (list is! List) return const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(ComixComic.fromJson)
        .toList();
  }

  Future<List<ComixChapter>> fetchChapters(
    OpsSettings settings,
    int comicId,
  ) async {
    final json = await _getJson(settings, '/API/comix/chapters/$comicId');
    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      throw const ComixApiException('chapters 接口返回结构异常');
    }
    final list = data['chapters'];
    if (list is! List) return const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(ComixChapter.fromJson)
        .toList();
  }

  // --- 异步任务接口 ---

  /// 启动一个异步任务，返回 task_id。
  Future<String> startTask(
    OpsSettings settings,
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final json = await _request(settings, 'POST', '/API/comix/$endpoint', body: body);
    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      throw const ComixApiException('启动任务接口返回结构异常');
    }
    final taskId = data['task_id'] as String?;
    if (taskId == null || taskId.isEmpty) {
      throw const ComixApiException('启动任务接口缺少 task_id');
    }
    return taskId;
  }

  Future<List<ComixTask>> fetchTasks(OpsSettings settings) async {
    final json = await _getJson(settings, '/API/comix/tasks');
    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      throw const ComixApiException('tasks 接口返回结构异常');
    }
    final list = data['tasks'];
    if (list is! List) return const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(ComixTask.fromJson)
        .toList();
  }

  /// 按详情页 URL 批量启动下载任务（服务端自动识别站点，多个 URL 并发）。
  /// 返回每个 URL 的提交结果：{url, site?, task_id?, status?, error?}。
  Future<List<Map<String, dynamic>>> downloadUrls(
    OpsSettings settings,
    List<String> urls, {
    int? latest,
  }) async {
    final json = await _request(
      settings,
      'POST',
      '/API/comix/download-url',
      body: <String, dynamic>{
        'urls': urls,
        if (latest != null) 'latest': latest,
      },
    );
    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      throw const ComixApiException('download-url 接口返回结构异常');
    }
    final list = data['tasks'];
    if (list is! List) return const [];
    return list.whereType<Map<String, dynamic>>().toList();
  }

  Future<ComixTask> fetchTask(OpsSettings settings, String taskId) async {
    final json = await _getJson(settings, '/API/comix/tasks/$taskId');
    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      throw const ComixApiException('task 详情接口返回结构异常');
    }
    return ComixTask.fromJson(data);
  }

  Future<void> stopTask(OpsSettings settings, String taskId) async {
    await _request(settings, 'POST', '/API/comix/tasks/$taskId/stop');
  }

  /// 同步删除漫画（Go 端直查库：DB 级联 + 文件删除）。
  /// 大漫画的文件删除可能耗时，超时放宽至 120s。
  Future<Map<String, dynamic>> deleteComic(
    OpsSettings settings,
    int comicId, {
    bool keepFiles = false,
  }) async {
    return _request(
      settings,
      'POST',
      '/API/comix/delete',
      body: <String, dynamic>{'comic_id': comicId, 'keep_files': keepFiles},
      timeout: const Duration(seconds: 120),
    );
  }

  // --- 内部工具 ---

  Future<Map<String, dynamic>> _getJson(
    OpsSettings settings,
    String endpoint,
  ) async {
    final uri = _buildUri(settings.apiBaseUrl, endpoint);
    final client = _getClient(uri);
    final headers = _buildHeaders(settings);

    final request = await client.getUrl(uri);
    headers.forEach(request.headers.set);
    final response = await request.close().timeout(const Duration(seconds: 30));
    final body = await response.transform(utf8.decoder).join();

    return _decode(settings, response.statusCode, body);
  }

  Future<Map<String, dynamic>> _request(
    OpsSettings settings,
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final uri = _buildUri(settings.apiBaseUrl, endpoint);
    final client = _getClient(uri);
    final headers = _buildHeaders(settings);
    headers['Content-Type'] = 'application/json';

    final request = await client.openUrl(method, uri);
    headers.forEach(request.headers.set);

    if (body != null) {
      final bytes = utf8.encode(jsonEncode(body));
      request.contentLength = bytes.length;
      request.add(bytes);
    }

    final response = await request.close().timeout(timeout);
    final responseBody = await response.transform(utf8.decoder).join();
    return _decode(settings, response.statusCode, responseBody);
  }

  /// 统一解码：HTTP 非 2xx 或业务 ok=false 抛 [ComixApiException]。
  Map<String, dynamic> _decode(
    OpsSettings settings,
    int statusCode,
    String body,
  ) {
    if (statusCode < 200 || statusCode >= 300) {
      var detail = '';
      Map<String, dynamic>? payload;
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) {
          payload = decoded;
          if (decoded['error'] is String) {
            detail = ': ${decoded['error']}';
          }
        }
      } catch (_) {
        // 非 JSON 响应体
      }
      throw ComixApiException(
        '接口请求失败: HTTP $statusCode$detail',
        statusCode: statusCode,
        payload: payload,
      );
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const ComixApiException('接口返回不是对象结构');
    }

    if (decoded['ok'] == false) {
      throw ComixApiException(
        decoded['error'] as String? ?? '未知业务错误',
        statusCode: statusCode,
        payload: decoded,
      );
    }
    return decoded;
  }

  Map<String, String> _buildHeaders(OpsSettings settings) {
    final headers = <String, String>{'Accept': 'application/json'};
    final apiKey = settings.apiKey.trim();
    if (apiKey.isNotEmpty) {
      headers['X-API-Key'] = apiKey;
    }
    return headers;
  }

  Uri _buildUri(String base, String endpoint) {
    final normalizedBase = base.trim().replaceAll(RegExp(r'/+$'), '');
    final normalizedEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    return Uri.parse('$normalizedBase$normalizedEndpoint');
  }
}
