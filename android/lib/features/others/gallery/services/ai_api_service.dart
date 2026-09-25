import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/core/services/network/api_client.dart';
import 'package:torrid/features/others/gallery/models/ai_search_models.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

/// 智能相册服务端接口（`/API/ai/*`）。
///
/// 只提供只读检索与人物分组；AI 任务的入队/重试等运维操作由桌面端负责，
/// Android 端不提供写入口，避免误触触发大批量处理。
///
/// 依赖几乎不变，故用普通 Provider 而非代码生成（与桌面端同一取舍）。
final aiApiProvider = Provider<AiApiService>((ref) {
  return AiApiService(ref.watch(apiClientManagerProvider));
});

class AiApiService {
  AiApiService(this._client);

  final ApiClient _client;

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e) {
      throw ApiClient.mapError(e);
    }
  }

  /// 组合检索：q 为自然语言或关键词；mode 为 auto/semantic/keyword。
  Future<AiSearchResult> search(
    String query, {
    String mode = 'auto',
    String? mimeType,
    int limit = 60,
    int offset = 0,
  }) {
    return _guard(() async {
      final resp = await _client.get(
        '/API/ai/search',
        queryParams: {
          if (query.trim().isNotEmpty) 'q': query.trim(),
          'mode': mode,
          if (mimeType != null && mimeType.isNotEmpty) 'mime_type': mimeType,
          'limit': limit,
          'offset': offset,
        },
      );
      return AiSearchResult.fromJson(resp.data as Map<String, dynamic>);
    });
  }

  /// 以图搜图：以库内某张图为查询，返回相似媒体。
  Future<AiSearchResult> similar(String mediaId, {int limit = 60}) {
    return _guard(() async {
      final resp = await _client.get(
        '/API/ai/similar/$mediaId',
        queryParams: {'limit': limit},
      );
      return AiSearchResult.fromJson(resp.data as Map<String, dynamic>);
    });
  }

  /// 人物分组列表。
  Future<List<AiPerson>> fetchPersons() {
    return _guard(() async {
      final resp = await _client.get('/API/ai/persons');
      final data = resp.data as Map<String, dynamic>;
      return [
        for (final item in (data['persons'] as List? ?? const []))
          if (item is Map<String, dynamic>) AiPerson.fromJson(item),
      ];
    });
  }

  /// 按人物筛选其全部媒体。
  Future<AiSearchResult> searchByPerson(String personId, {int limit = 60}) {
    return _guard(() async {
      final resp = await _client.get(
        '/API/ai/search',
        queryParams: {
          'mode': 'keyword',
          'person_ids': personId,
          'limit': limit,
        },
      );
      return AiSearchResult.fromJson(resp.data as Map<String, dynamic>);
    });
  }
}
