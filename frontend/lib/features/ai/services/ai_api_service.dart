import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/core/api/generated/api_contract.dart' show ApiPath;
import 'package:torrid/core/services/network/api_client.dart';
import 'package:torrid/features/ai/models/ai_search_models.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

/// 服务端 AI 接口（`/API/ai/*`）。
///
/// 只提供只读能力：检索、人物分组、AI 标签清单。AI 任务的入队/重试等运维操作
/// 由运维端(ops)负责，本端不提供写入口，避免误触触发大批量处理。
///
/// 依赖几乎不变，故用普通 Provider 而非代码生成。
final aiApiProvider = Provider<AiApiService>((ref) {
  return AiApiService(ref.watch(apiClientManagerProvider));
});

/// 检索模式：与后端 `mode` 参数一致。
///
/// `auto`（智能）在有文本查询时走语义检索，语义链路不可用时自动退化为关键词，
/// 因此不再单独暴露 `semantic`。
enum AiSearchMode {
  auto('auto', '智能'),
  keyword('keyword', '文字'),
  filename('filename', '文件名');

  const AiSearchMode(this.value, this.label);

  final String value;
  final String label;
}

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

  /// 组合检索：q 为自然语言、关键词或文件名片段。
  ///
  /// [filename] 模式只匹配文件路径，因此"`.mp4`"这类扩展名查询也能命中。
  Future<AiSearchResult> search(
    String query, {
    AiSearchMode mode = AiSearchMode.auto,
    List<String> vlmTags = const [],
    String? mimeType,
    int limit = 60,
    int offset = 0,
  }) {
    return _guard(() async {
      final resp = await _client.get(
        ApiPath.aiSearch,
        queryParams: {
          if (query.trim().isNotEmpty) 'q': query.trim(),
          'mode': mode.value,
          if (vlmTags.isNotEmpty) 'vlm_tags': vlmTags.join(','),
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
        ApiPath.aiSimilarIdPath(mediaId),
        queryParams: {'limit': limit},
      );
      return AiSearchResult.fromJson(resp.data as Map<String, dynamic>);
    });
  }

  /// 人物分组列表。
  Future<List<AiPerson>> fetchPersons() {
    return _guard(() async {
      final resp = await _client.get(ApiPath.aiPersons);
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
        ApiPath.aiSearch,
        queryParams: {
          'mode': 'keyword',
          'person_ids': personId,
          'limit': limit,
        },
      );
      return AiSearchResult.fromJson(resp.data as Map<String, dynamic>);
    });
  }

  /// AI 标签清单（含出现次数）。AI 层未初始化时由服务端返回 503，调用方据此隐藏入口。
  Future<List<AiTagCount>> fetchTags({int limit = 500}) {
    return _guard(() async {
      final resp = await _client.get(
        ApiPath.aiTags,
        queryParams: {'limit': limit},
      );
      final data = resp.data as Map<String, dynamic>;
      return [
        for (final item in (data['tags'] as List? ?? const []))
          if (item is Map<String, dynamic>) AiTagCount.fromJson(item),
      ];
    });
  }

  /// 单个媒体的 AI 分析结果（描述 / 关键词 / OCR）。
  Future<AiMediaDetail> fetchMediaDetail(String mediaId) {
    return _guard(() async {
      final resp = await _client.get(ApiPath.aiMediaIdPath(mediaId));
      return AiMediaDetail.fromJson(resp.data as Map<String, dynamic>);
    });
  }
}
