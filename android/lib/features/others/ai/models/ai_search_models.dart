/// 智能检索（AI）相关模型。
///
/// 只包含 Android 端消费所需的最小字段：命中媒体的展示信息、相关度与命中来源。
library;

import 'package:torrid/features/others/gallery/models/media_asset.dart';

/// 一条检索命中。
class AiSearchHit {
  final String id;
  final String filePath;
  final String? mimeType;
  final DateTime capturedAt;
  final int sizeBytes;
  final double score;
  final List<String> source;

  const AiSearchHit({
    required this.id,
    required this.filePath,
    this.mimeType,
    required this.capturedAt,
    this.sizeBytes = 0,
    this.score = 0,
    this.source = const [],
  });

  factory AiSearchHit.fromJson(Map<String, dynamic> json) {
    return AiSearchHit(
      id: (json['id'] ?? '').toString(),
      filePath: (json['file_path'] ?? '').toString(),
      mimeType: json['mime_type'] as String?,
      capturedAt: _parseTime(json['captured_at']),
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      score: (json['score'] as num?)?.toDouble() ?? 0,
      source: [
        for (final item in (json['source'] as List? ?? const []))
          item.toString(),
      ],
    );
  }

  /// 转为通用媒体模型，供全屏查看器复用。
  ///
  /// 检索结果不含缩略图路径与编辑参数（本端不写本地缓存），保持为空即可。
  MediaAsset toAsset() => MediaAsset(
        id: id,
        createdAt: capturedAt,
        updatedAt: capturedAt,
        capturedAt: capturedAt,
        filePath: filePath,
        hash: '',
        sizeBytes: sizeBytes,
        mimeType: mimeType,
      );

  /// 缩略图地址（复用画廊文件流接口）。
  String thumbUrl(String baseUrl) => '$baseUrl/API/gallery/$id/thumb';

  bool get isVideo => (mimeType ?? '').startsWith('video/');

  /// 文件名的最后一段，用于列表展示。
  String get fileName {
    final segments = filePath.split(RegExp(r'[/\\]'));
    return segments.isEmpty ? filePath : segments.last;
  }
}

/// 检索结果集。
class AiSearchResult {
  final List<AiSearchHit> hits;
  final int total;
  final String mode;

  const AiSearchResult({
    this.hits = const [],
    this.total = 0,
    this.mode = '',
  });

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

  String get displayName =>
      (name == null || name!.isEmpty) ? '未命名人物' : name!;
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

/// 解析服务端时间；缺失或非法时退化为当前时间，避免整条结果解析失败。
DateTime _parseTime(Object? raw) {
  if (raw is String && raw.isNotEmpty) {
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed;
  }
  return DateTime.now();
}
