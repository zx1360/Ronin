import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/core/services/network/api_client.dart';
import 'package:torrid/features/chat/models/review_models.dart';
import 'package:torrid/features/chat/services/chat_api_service.dart';
import 'package:torrid/features/essay/services/essay_contract.dart';
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
  }) async* {
    try {
      final response = await _client.postJson(
        '/API/user-data/check-images/essay',
        data: {'filenames': <String>[]},
        cancelToken: cancelToken,
      );
      requireEssaySchema(response.data);
    } catch (e) {
      throw ApiClient.mapError(e);
    }
    yield* streamNdjsonEvents(
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
    if (data is! Map || data['presets'] is! List) {
      throw const FormatException('服务端返回了无效的回顾预设');
    }
    final presets = (data['presets'] as List)
        .map(
          (item) =>
              ReviewPreset.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    final ids = <String>{};
    if (presets.any(
      (preset) =>
          preset.id.isEmpty || !ids.add(preset.id) || preset.problem != null,
    )) {
      throw const FormatException('回顾预设缺少必要字段或 ID 重复');
    }
    return presets;
  }
}
