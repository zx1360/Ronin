import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/core/services/network/api_client.dart';
import 'package:torrid/features/chat/models/review_models.dart';
import 'package:torrid/features/chat/services/chat_api_service.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

/// 服务端回顾接口（`/API/ai/review*`）。
final reviewApiProvider = Provider<ReviewApiService>((ref) {
  return ReviewApiService(ref.watch(apiClientManagerProvider));
});

class ReviewApiService {
  ReviewApiService(this._client);

  final ApiClient _client;

  /// 生成一次回顾：NDJSON 流，正文之前先来一条 `stats` 事件（本次依据的确定性统计）。
  Stream<ChatStreamEvent> generate({
    required Map<String, dynamic> request,
    CancelToken? cancelToken,
  }) {
    return streamNdjsonEvents(
      _client,
      '/API/ai/review',
      request,
      cancelToken: cancelToken,
      failureLabel: '回顾请求',
    );
  }

  /// 读取服务端预设（权威副本）。
  Future<List<ReviewPreset>> fetchPresets() async {
    try {
      final response = await _client.get('/API/ai/review/presets');
      return _parsePresets(response.data);
    } catch (e) {
      throw ApiClient.mapError(e);
    }
  }

  /// 整体替换服务端预设，返回服务端规整后的列表。
  Future<List<ReviewPreset>> savePresets(List<ReviewPreset> presets) async {
    try {
      final response = await _client.putJson(
        '/API/ai/review/presets',
        data: {
          'presets': [for (final preset in presets) preset.toJson()],
        },
      );
      return _parsePresets(response.data);
    } catch (e) {
      throw ApiClient.mapError(e);
    }
  }

  List<ReviewPreset> _parsePresets(dynamic data) {
    if (data is! Map<String, dynamic>) return const [];
    return [
      for (final item in (data['presets'] as List? ?? const []))
        if (item is Map<String, dynamic>) ReviewPreset.fromJson(item),
    ];
  }
}
