import 'dart:convert';

import 'package:northstar/domain/ops/models/ops_overview.dart';
import 'package:northstar/domain/ops/models/ops_settings.dart';
import 'package:northstar/infrastructure/api_http_helper.dart';

/// 统一 Ops API 异常
///
/// 将 HTTP 状态码与响应体归一化为可读异常，供 UI 层统一展示，
/// 避免各页面各自拼装错误信息。
class OpsApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? body;

  const OpsApiException(this.message, {this.statusCode, this.body});

  @override
  String toString() => message;
}

class OpsApiClient {
  final ApiHttpClientHolder _http = ApiHttpClientHolder(
    connectTimeout: const Duration(seconds: 6),
  );

  /// 释放底层 HttpClient
  void dispose() {
    _http.dispose();
  }

  /// 根据 URL 协议请求监控接口
  Future<OpsOverview> fetchOverview(OpsSettings settings) async {
    final parsed = await _getJson(settings, '/API/ops/overview');
    return OpsOverview.fromJson(parsed.cast<String, dynamic>());
  }

  // --- 内部工具 ---

  Future<Map<String, dynamic>> _getJson(
    OpsSettings settings,
    String endpoint,
  ) async {
    final uri = buildApiUri(settings.apiBaseUrl, endpoint);
    final client = _http.clientFor(uri);
    final headers = buildApiHeaders(settings.apiKey);

    final request = await client.getUrl(uri);
    headers.forEach(request.headers.set);
    final response = await request.close().timeout(const Duration(seconds: 20));
    final responseBody = await response.transform(utf8.decoder).join();

    _throwIfNotOk(response.statusCode, body: responseBody);

    final decoded = jsonDecode(responseBody);
    if (decoded is! Map) {
      throw Exception('接口返回不是对象结构');
    }
    return Map<String, dynamic>.from(decoded);
  }

  /// 非 2xx 状态统一抛出 [OpsApiException]，并附带服务端错误体（若可解析）。
  void _throwIfNotOk(int statusCode, {String? body}) {
    if (statusCode >= 200 && statusCode < 300) {
      return;
    }

    final detail = apiErrorDetailOf(tryDecodeJsonMap(body ?? ''));
    throw OpsApiException(
      '接口请求失败: HTTP $statusCode$detail',
      statusCode: statusCode,
      body: body,
    );
  }
}
