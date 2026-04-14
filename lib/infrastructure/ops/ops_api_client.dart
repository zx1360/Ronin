import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:northstar/domain/ops/models/ops_overview.dart';
import 'package:northstar/domain/ops/models/ops_settings.dart';

class OpsApiClient {
  Future<OpsOverview> fetchOverview(OpsSettings settings) async {
    final uri = _buildUri(settings.apiBaseUrl, '/api/ops/overview');

    final headers = <String, String>{
      'Accept': 'application/json',
    };
    final apiKey = settings.apiKey.trim();
    if (apiKey.isNotEmpty) {
      headers['X-API-Key'] = apiKey;
    }

    final response = await http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 6));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('接口请求失败: HTTP ${response.statusCode}');
    }

    final parsed = jsonDecode(response.body);
    if (parsed is! Map) {
      throw Exception('接口返回不是对象结构');
    }

    return OpsOverview.fromJson(parsed.cast<String, dynamic>());
  }

  Uri _buildUri(String base, String endpoint) {
    final normalizedBase = base.trim().replaceAll(RegExp(r'/+$'), '');
    final normalizedEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    final target = '$normalizedBase$normalizedEndpoint';
    return Uri.parse(target);
  }
}
