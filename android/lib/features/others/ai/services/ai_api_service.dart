import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/core/services/network/api_client.dart';
import 'package:torrid/features/others/ai/models/ai_search_models.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

/// 把 AI 接口错误转成用户能理解的提示。
///
/// 服务端未启用 AI 能力（AI_ENABLED=false）或 AI 表未初始化时统一返回 503
String aiFriendlyError(Object error) {
  if (error is ApiException && error.statusCode == 503) {
    return '服务端未启用 AI 能力（或 AI 数据表未初始化），请在桌面端开启后重试';
  }
  return error.toString();
}

/// 服务端 AI 接口（`/API/ai/*`）。
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

  /// capabilityLabels 的短期缓存（能力清单几乎不变，每次错误提示都请求不划算）。
  ({Map<String, String> labels, DateTime at})? _capabilityLabels;

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
        '/API/ai/search',
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

  /// AI 标签清单（含出现次数）。AI 层未初始化时由服务端返回 503，调用方据此隐藏入口。
  Future<List<AiTagCount>> fetchTags({int limit = 500}) {
    return _guard(() async {
      final resp = await _client.get(
        '/API/ai/tags',
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
      final resp = await _client.get('/API/ai/media/$mediaId');
      return AiMediaDetail.fromJson(resp.data as Map<String, dynamic>);
    });
  }

  /// 能力标识 → 展示名（服务端下发），用于把错误里的能力标识换成可读名称。
  ///
  /// 结果缓存 5 分钟；取不到时返回空表，调用方原样显示标识即可，不影响功能。
  Future<Map<String, String>> capabilityLabels() async {
    final cached = _capabilityLabels;
    if (cached != null &&
        DateTime.now().difference(cached.at) < const Duration(minutes: 5)) {
      return cached.labels;
    }
    try {
      final resp = await _client.get('/API/ai/capabilities');
      final data = resp.data as Map<String, dynamic>;
      final labels = <String, String>{};
      for (final item in (data['capabilities'] as List? ?? const [])) {
        if (item is Map<String, dynamic>) {
          final id = (item['capability'] ?? '').toString();
          final label = (item['label'] ?? '').toString();
          if (id.isNotEmpty && label.isNotEmpty) labels[id] = label;
        }
      }
      _capabilityLabels = (labels: labels, at: DateTime.now());
      return labels;
    } catch (_) {
      return const {};
    }
  }
}
