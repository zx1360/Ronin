import 'dart:convert';
import 'dart:io';

import 'package:northstar/domain/ops/models/ops_overview.dart';
import 'package:northstar/domain/ops/models/ops_settings.dart';
import 'package:northstar/services/cert_trust.dart';

class OpsApiClient {
  /// 根据 URL 协议请求监控接口：http 使用普通连接，https 使用内置证书信任连接。
  Future<OpsOverview> fetchOverview(OpsSettings settings) async {
    final uri = _buildUri(settings.apiBaseUrl, '/API/ops/overview');
    final client = _buildHttpClient(uri);

    final headers = _buildHeaders(settings);

    try {
      final request = await client.getUrl(uri);
      headers.forEach(request.headers.set);
      final response = await request.close().timeout(const Duration(seconds: 6));
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('接口请求失败: HTTP ${response.statusCode}');
      }

      final parsed = jsonDecode(responseBody);
      if (parsed is! Map) {
        throw Exception('接口返回不是对象结构');
      }

      return OpsOverview.fromJson(parsed.cast<String, dynamic>());
    } finally {
      client.close(force: true);
    }
  }

  // --- 漫画管理 API ---

  /// 获取所有漫画列表
  Future<List<Map<String, dynamic>>> fetchComics(OpsSettings settings) async {
    return _getJsonList(settings, '/API/comic/comic-info');
  }

  /// 更新漫画元数据 (is_public / readed / source / cover_image)
  Future<void> updateComic(OpsSettings settings, String comicId, Map<String, dynamic> body) async {
    await _request(settings, 'PUT', '/API/comic/comic-info/$comicId', body: body);
  }

  /// 删除漫画（数据库 + 文件系统）
  Future<void> deleteComic(OpsSettings settings, String comicId) async {
    await _request(settings, 'DELETE', '/API/comic/comic-info/$comicId');
  }

  // --- 内部工具 ---

  Future<List<Map<String, dynamic>>> _getJsonList(OpsSettings settings, String endpoint) async {
    final uri = _buildUri(settings.apiBaseUrl, endpoint);
    final client = _buildHttpClient(uri);
    final headers = _buildHeaders(settings);

    try {
      final request = await client.getUrl(uri);
      headers.forEach(request.headers.set);
      final response = await request.close().timeout(const Duration(seconds: 10));
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('接口请求失败: HTTP ${response.statusCode}');
      }

      final parsed = jsonDecode(body);
      if (parsed is! List) {
        throw Exception('接口返回不是数组结构');
      }

      return parsed.cast<Map<String, dynamic>>();
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _request(
    OpsSettings settings,
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final uri = _buildUri(settings.apiBaseUrl, endpoint);
    final client = _buildHttpClient(uri);
    final headers = _buildHeaders(settings);
    headers['Content-Type'] = 'application/json';

    try {
      final request = await client.openUrl(method, uri);
      headers.forEach(request.headers.set);

      if (body != null) {
        final jsonBytes = utf8.encode(jsonEncode(body));
        request.contentLength = jsonBytes.length;
        request.add(jsonBytes);
      }

      final response = await request.close().timeout(const Duration(seconds: 10));
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('接口请求失败: HTTP ${response.statusCode} $responseBody');
      }

      final parsed = jsonDecode(responseBody);
      return (parsed as Map).cast<String, dynamic>();
    } finally {
      client.close(force: true);
    }
  }

  Map<String, String> _buildHeaders(OpsSettings settings) {
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    final apiKey = settings.apiKey.trim();
    if (apiKey.isNotEmpty) {
      headers['X-API-Key'] = apiKey;
    }
    return headers;
  }

  Uri _buildUri(String base, String endpoint) {
    final normalizedBase = base.trim().replaceAll(RegExp(r'/+$'), '');
    final normalizedEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    final target = '$normalizedBase$normalizedEndpoint';
    return Uri.parse(target);
  }

  /// 根据协议创建 HttpClient: https 复用 CertTrust 的安全上下文.
  HttpClient _buildHttpClient(Uri uri) {
    if (uri.scheme.toLowerCase() != 'https') {
      return HttpClient()..connectionTimeout = const Duration(seconds: 6);
    }
    return CertTrust.createSecureClient();
  }
}
