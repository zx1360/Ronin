import 'dart:convert';
import 'dart:io';

import 'package:northstar/services/cert_trust.dart';

/// 归一化 base URL：去掉首尾空白与末尾斜杠，避免拼出 `//API/...`。
String normalizeBaseUrl(String base) {
  return base.trim().replaceAll(RegExp(r'/+$'), '');
}

/// 拼接 base + endpoint（endpoint 允许带或不带前导 '/'）。
Uri buildApiUri(String base, String endpoint) {
  final normalizedBase = normalizeBaseUrl(base);
  final normalizedEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
  return Uri.parse('$normalizedBase$normalizedEndpoint');
}

/// 生成请求头（Accept + 可选的 X-API-Key）。
Map<String, String> buildApiHeaders(String apiKey) {
  final headers = <String, String>{'Accept': 'application/json'};
  final trimmedKey = apiKey.trim();
  if (trimmedKey.isNotEmpty) {
    headers['X-API-Key'] = trimmedKey;
  }
  return headers;
}

/// 尽力把响应体解析为 JSON 对象；非对象或解析失败返回 null。
Map<String, dynamic>? tryDecodeJsonMap(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
  } catch (_) {
    // 非 JSON 响应体
  }
  return null;
}

/// 从错误响应体中提取服务端 `error` 文案，拼成冒号后缀；无则返回空串。
String apiErrorDetailOf(Map<String, dynamic>? payload) {
  final error = payload?['error'];
  return error is String ? ': $error' : '';
}

/// 两个 API 客户端共用的 HttpClient 生命周期：按 origin 复用，变更时重建。
///
/// [connectTimeout] 只作用于明文 HTTP 客户端；HTTPS 复用
/// [CertTrust.createSecureClient] 的默认超时。
class ApiHttpClientHolder {
  ApiHttpClientHolder({required this.connectTimeout});

  final Duration connectTimeout;

  HttpClient? _client;
  Uri? _lastBaseUri;

  /// 获取或创建复用的 HttpClient（base URL 变更时重建）。
  HttpClient clientFor(Uri uri) {
    final isHttps = uri.scheme.toLowerCase() == 'https';
    if (_client != null && _lastBaseUri?.origin == uri.origin) {
      return _client!;
    }
    _client?.close(force: true);
    _client = isHttps
        ? CertTrust.createSecureClient()
        : (HttpClient()..connectionTimeout = connectTimeout);
    _lastBaseUri = uri;
    return _client!;
  }

  /// 释放底层 HttpClient。
  void dispose() {
    _client?.close(force: true);
    _client = null;
    _lastBaseUri = null;
  }
}
