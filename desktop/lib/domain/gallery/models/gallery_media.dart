/// 画廊媒体模型（`/API/gallery/media` 的 `media_assets` 元素）。
///
/// 桌面端只用到「清理重复/软删除」相关字段，其余保持缺省即可。
library;

int _int(dynamic value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  return fallback;
}

class GalleryMedia {
  final String id;
  final String filePath;
  final String? mimeType;
  final String? capturedAt;
  final int sizeBytes;
  final bool isDeleted;

  const GalleryMedia({
    required this.id,
    required this.filePath,
    this.mimeType,
    this.capturedAt,
    required this.sizeBytes,
    required this.isDeleted,
  });

  factory GalleryMedia.fromJson(Map<String, dynamic> json) {
    return GalleryMedia(
      id: (json['id'] ?? '').toString(),
      filePath: (json['file_path'] ?? '').toString(),
      mimeType: json['mime_type'] as String?,
      capturedAt: json['captured_at'] as String?,
      sizeBytes: _int(json['size_bytes']),
      isDeleted: json['is_deleted'] == true,
    );
  }

  bool get isVideo => (mimeType ?? '').startsWith('video/');

  /// 路径最后一段（兼容两种分隔符）。
  String get fileName {
    final segments = filePath.split(RegExp(r'[/\\]'));
    return segments.isEmpty ? filePath : segments.last;
  }
}

/// 一页媒体查询结果。
class GalleryMediaPage {
  final List<GalleryMedia> items;
  final int total;

  const GalleryMediaPage({required this.items, required this.total});
}
