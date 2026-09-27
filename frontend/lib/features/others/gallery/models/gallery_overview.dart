/// 服务端画廊总览数据模型 - 对应 GET /API/gallery/overview 响应
library;

import 'package:json_annotation/json_annotation.dart';

part 'gallery_overview.g.dart';

@JsonSerializable()
class GalleryOverview {
  @JsonKey(name: 'total_media')
  final int totalMedia;
  @JsonKey(name: 'image_count')
  final int imageCount;
  @JsonKey(name: 'video_count')
  final int videoCount;
  @JsonKey(name: 'image_ratio')
  final double imageRatio;
  @JsonKey(name: 'video_ratio')
  final double videoRatio;
  @JsonKey(name: 'total_tags')
  final int totalTags;
  @JsonKey(name: 'root_tags')
  final int rootTags;
  @JsonKey(name: 'total_links')
  final int totalLinks;
  @JsonKey(name: 'total_size')
  final int totalSize;
  @JsonKey(name: 'min_year')
  final int minYear;
  @JsonKey(name: 'max_year')
  final int maxYear;
  @JsonKey(name: 'sync_stats')
  final SyncStatsData syncStats;
  @JsonKey(name: 'year_stats')
  final List<YearStatItem> yearStats;

  const GalleryOverview({
    required this.totalMedia,
    required this.imageCount,
    required this.videoCount,
    required this.imageRatio,
    required this.videoRatio,
    required this.totalTags,
    required this.rootTags,
    required this.totalLinks,
    required this.totalSize,
    required this.minYear,
    required this.maxYear,
    required this.syncStats,
    required this.yearStats,
  });

  factory GalleryOverview.fromJson(Map<String, dynamic> json) =>
      _$GalleryOverviewFromJson(json);

  /// 格式化总大小
  String get formattedSize {
    if (totalSize < 1024) return '$totalSize B';
    if (totalSize < 1024 * 1024) {
      return '${(totalSize / 1024).toStringAsFixed(1)} KB';
    }
    if (totalSize < 1024 * 1024 * 1024) {
      return '${(totalSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(totalSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// 图片占比百分比
  String get imagePercent => '${(imageRatio * 100).toStringAsFixed(1)}%';

  /// 视频占比百分比
  String get videoPercent => '${(videoRatio * 100).toStringAsFixed(1)}%';
}

@JsonSerializable()
class SyncStatsData {
  @JsonKey(name: 'min_sync_count')
  final int minSyncCount;
  @JsonKey(name: 'max_sync_count')
  final int maxSyncCount;
  @JsonKey(name: 'avg_sync_count')
  final double avgSyncCount;

  const SyncStatsData({
    required this.minSyncCount,
    required this.maxSyncCount,
    required this.avgSyncCount,
  });

  factory SyncStatsData.fromJson(Map<String, dynamic> json) =>
      _$SyncStatsDataFromJson(json);
}

@JsonSerializable()
class YearStatItem {
  final int year;
  @JsonKey(name: 'media_count')
  final int mediaCount;

  const YearStatItem({
    required this.year,
    required this.mediaCount,
  });

  factory YearStatItem.fromJson(Map<String, dynamic> json) =>
      _$YearStatItemFromJson(json);
}
