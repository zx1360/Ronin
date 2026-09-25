/// 智能检索（AI）相关模型。
///
/// 只包含 Android 端消费所需的最小字段：命中媒体的标识与展示信息、
/// 相关度与命中来源。
library;

/// 一条检索命中。
class AiSearchHit {
  final String id;
  final String filePath;
  final String? mimeType;
  final String? capturedAt;
  final double score;
  final List<String> source;

  const AiSearchHit({
    required this.id,
    required this.filePath,
    this.mimeType,
    this.capturedAt,
    this.score = 0,
    this.source = const [],
  });

  factory AiSearchHit.fromJson(Map<String, dynamic> json) {
    return AiSearchHit(
      id: (json['id'] ?? '').toString(),
      filePath: (json['file_path'] ?? '').toString(),
      mimeType: json['mime_type'] as String?,
      capturedAt: json['captured_at'] as String?,
      score: (json['score'] as num?)?.toDouble() ?? 0,
      source: [
        for (final item in (json['source'] as List? ?? const []))
          item.toString(),
      ],
    );
  }

  /// 缩略图地址（复用画廊文件流接口）。
  String thumbUrl(String baseUrl) => '$baseUrl/API/gallery/$id/thumb';

  bool get isVideo => (mimeType ?? '').startsWith('video/');

  /// 文件名的最后一段，用于列表展示。
  String get fileName {
    final segments = filePath.split('/');
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
