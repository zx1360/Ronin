/// "近期回顾"的服务端接口（`/API/ai/review*`）。
///
/// 分工是刻意的：统计由后端从库中算出（`stats` / `facts`），本地模型只写叙述；
/// 结果按"统计指纹 + 预设 + 模型"在后端缓存，页面不存任何预设。
/// 模型不可用时接口仍返回统计并给出 `notice`（完整降级）。
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/core/api/generated/api_contract.dart';
import 'package:torrid/core/services/network/api_client.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

/// 回顾窗口的默认值与上限，与后端 `review.DefaultDays` / `review.MaxDays` 一致。
const int defaultReviewDays = 30;
const int maxReviewDays = 365;
const int minReviewDays = 1;

/// 生成回顾时的接收超时：本地模型写几百字可能要好几分钟。
const Duration _reviewReceiveTimeout = Duration(minutes: 10);

final reviewApiProvider = Provider<ReviewApiService>((ref) {
  return ReviewApiService(ref.watch(apiClientManagerProvider));
});

class ReviewApiService {
  ReviewApiService(this._client);

  final ApiClient _client;

  /// 列出全部预设（默认预设排首位）。
  Future<List<ReviewPreset>> listPresets() async {
    try {
      final response = await _client.get(ApiPath.aiReviewPresets);
      return _presetsOf(response.data);
    } catch (e) {
      throw _apiError(e);
    }
  }

  /// 新建（[id] 为空）或更新预设；[isDefault] 为真时服务端会取消其它预设的默认标记。
  Future<List<ReviewPreset>> upsertPreset({
    String? id,
    required String name,
    required String tone,
    required String role,
    required bool isDefault,
  }) async {
    try {
      final response = await _client.postJson(
        ApiPath.aiReviewPresetsPost,
        data: {
          'id': id ?? '',
          'name': name,
          'tone': tone,
          'role': role,
          'is_default': isDefault,
        },
      );
      return _presetsOf(response.data);
    } catch (e) {
      throw _apiError(e);
    }
  }

  /// 删除预设（默认预设不可删除，服务端会返回原因）。
  Future<List<ReviewPreset>> deletePreset(String id) async {
    try {
      final response = await _client.delete(ApiPath.aiReviewPresetsIdPath(id));
      return _presetsOf(response.data);
    } catch (e) {
      throw _apiError(e);
    }
  }

  /// 生成回顾。
  ///
  /// 这个接口**不是流式**的：本地模型写完整段叙述才返回，可能要几分钟。
  /// [ApiClient] 默认 15s 的接收超时对它是致命的，因此这里走
  /// [ApiClient.postStream]（可自定义接收超时），把响应体整段读回来再解析。
  Future<ReviewResult> generate({
    required int days,
    String? presetId,
    bool force = false,
    CancelToken? cancelToken,
  }) async {
    final Response<ResponseBody> response;
    try {
      response = await _client.postStream(
        ApiPath.aiReview,
        data: {
          'days': days,
          if (presetId != null && presetId.isNotEmpty) 'preset_id': presetId,
          'force': force,
        },
        cancelToken: cancelToken,
        receiveTimeout: _reviewReceiveTimeout,
      );
    } catch (e) {
      throw _apiError(e);
    }

    final stream = response.data?.stream;
    final body = stream == null ? '' : await _readAll(stream.cast<List<int>>());

    if (response.statusCode != 200) {
      throw ApiException(
        _errorOf(body) ?? '回顾请求失败 (HTTP ${response.statusCode ?? '-'})',
        statusCode: response.statusCode,
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      throw const ApiException('回顾响应格式异常');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('回顾响应格式异常');
    }
    return ReviewResult.fromJson(decoded);
  }

  List<ReviewPreset> _presetsOf(Object? data) {
    if (data is! Map) return const [];
    final raw = data['presets'];
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map<String, dynamic>) ReviewPreset.fromJson(item),
    ];
  }

  Future<String> _readAll(Stream<List<int>> stream) async {
    final bytes = <int>[];
    await for (final chunk in stream) {
      bytes.addAll(chunk);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// 服务端错误响应体里的 `error`（比统一的 HTTP 文案更有用）。
  String? _errorOf(String body) {
    final text = body.trim();
    if (text.isEmpty) return null;
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map && decoded['error'] != null) {
        return decoded['error'].toString();
      }
    } catch (_) {
      // 非 JSON 响应体就直接原文展示
    }
    return text;
  }

  /// 把底层异常归一化为 [ApiException]，优先取服务端给出的原因。
  ApiException _apiError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['error'] != null) {
        return ApiException(
          data['error'].toString(),
          statusCode: error.response?.statusCode,
          cause: error,
        );
      }
    }
    return ApiClient.mapError(error);
  }
}
