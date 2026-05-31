// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gallery_overview.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GalleryOverview _$GalleryOverviewFromJson(Map<String, dynamic> json) =>
    GalleryOverview(
      totalMedia: (json['total_media'] as num).toInt(),
      imageCount: (json['image_count'] as num).toInt(),
      videoCount: (json['video_count'] as num).toInt(),
      imageRatio: (json['image_ratio'] as num).toDouble(),
      videoRatio: (json['video_ratio'] as num).toDouble(),
      totalTags: (json['total_tags'] as num).toInt(),
      rootTags: (json['root_tags'] as num).toInt(),
      totalLinks: (json['total_links'] as num).toInt(),
      totalSize: (json['total_size'] as num).toInt(),
      minYear: (json['min_year'] as num).toInt(),
      maxYear: (json['max_year'] as num).toInt(),
      syncStats: SyncStatsData.fromJson(
          json['sync_stats'] as Map<String, dynamic>),
      yearStats: (json['year_stats'] as List<dynamic>)
          .map((e) => YearStatItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

SyncStatsData _$SyncStatsDataFromJson(Map<String, dynamic> json) =>
    SyncStatsData(
      minSyncCount: (json['min_sync_count'] as num).toInt(),
      maxSyncCount: (json['max_sync_count'] as num).toInt(),
      avgSyncCount: (json['avg_sync_count'] as num).toDouble(),
    );

YearStatItem _$YearStatItemFromJson(Map<String, dynamic> json) => YearStatItem(
      year: (json['year'] as num).toInt(),
      mediaCount: (json['media_count'] as num).toInt(),
    );
