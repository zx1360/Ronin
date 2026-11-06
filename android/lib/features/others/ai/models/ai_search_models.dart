/// 智能检索（AI）相关模型。
///
/// 只包含 Android 端消费所需的最小字段：命中媒体的展示信息、相关度与命中来源。
library;

import 'package:torrid/features/others/gallery/models/media_asset.dart';

class AiSearchHit {
  final MediaAsset asset;
  final double score;

  const AiSearchHit({required this.asset, required this.score});

  String get id => asset.id;

  factory AiSearchHit.fromJson(Map<String, dynamic> json) => AiSearchHit(
    asset: MediaAsset.fromJson(json),
    score: (json['score'] as num?)?.toDouble() ?? 0,
  );
}

/// 检索结果集。
class AiSearchResult {
  final List<AiSearchHit> hits;
  final int total;
  final String mode;

  const AiSearchResult({this.hits = const [], this.total = 0, this.mode = ''});

  static const empty = AiSearchResult();

  factory AiSearchResult.fromJson(Map<String, dynamic> json) {
    return AiSearchResult(
      hits: [
        for (final item in (json['hits'] as List? ?? const []))
          if (item is Map<String, dynamic>) AiSearchHit.fromJson(item),
      ],
      total: (json['total'] as num?)?.toInt() ?? 0,
      mode: (json['mode'] ?? '').toString(),
    );
  }
}

/// 人物分组（服务端人脸聚类结果）。
class AiPerson {
  final String id;
  final String? name;
  final String? coverMediaId;
  final int faceCount;

  const AiPerson({
    required this.id,
    this.name,
    this.coverMediaId,
    required this.faceCount,
  });

  factory AiPerson.fromJson(Map<String, dynamic> json) {
    return AiPerson(
      id: (json['id'] ?? '').toString(),
      name: json['name'] as String?,
      coverMediaId: json['cover_media_id'] as String?,
      faceCount: (json['face_count'] as num?)?.toInt() ?? 0,
    );
  }

  String get displayName => (name == null || name!.isEmpty) ? '未命名人物' : name!;
}

/// AI 标签及其出现次数（服务端聚合结果，只读）。
class AiTagCount {
  final String tag;
  final int count;

  const AiTagCount({required this.tag, required this.count});

  factory AiTagCount.fromJson(Map<String, dynamic> json) {
    return AiTagCount(
      tag: (json['tag'] ?? '').toString(),
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 单个媒体的 AI 分析结果。
class AiMediaDetail {
  final String mediaId;
  final String? caption;
  final String? ocrText;
  final List<String> vlmTags;
  final bool hasVector;

  const AiMediaDetail({
    required this.mediaId,
    this.caption,
    this.ocrText,
    this.vlmTags = const [],
    this.hasVector = false,
  });

  factory AiMediaDetail.fromJson(Map<String, dynamic> json) {
    return AiMediaDetail(
      mediaId: (json['media_id'] ?? '').toString(),
      caption: _nullIfEmpty(json['caption']),
      ocrText: _nullIfEmpty(json['ocr_text']),
      vlmTags: [
        for (final item in (json['vlm_tags'] as List? ?? const []))
          if (item.toString().trim().isNotEmpty) item.toString().trim(),
      ],
      hasVector: json['has_vector'] == true,
    );
  }

  /// 是否完全没有 AI 产物（用于展示"尚未处理"）。
  bool get isEmpty =>
      caption == null && ocrText == null && vlmTags.isEmpty && !hasVector;
}

String? _nullIfEmpty(Object? raw) {
  final text = (raw ?? '').toString().trim();
  return text.isEmpty ? null : text;
}
