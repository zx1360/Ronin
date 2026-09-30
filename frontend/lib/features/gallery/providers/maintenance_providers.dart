import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/gallery/providers/media_providers.dart';
import 'package:torrid/features/gallery/providers/service_providers.dart';
import 'package:torrid/features/gallery/providers/settings_providers.dart';
import 'package:torrid/features/gallery/providers/stats_providers.dart';
import 'package:torrid/features/gallery/providers/tag_providers.dart';
import 'package:torrid/features/gallery/services/gallery_sync_service.dart';

part 'maintenance_providers.g.dart';

/// 设置页维护操作状态
class GalleryMaintenanceState {
  const GalleryMaintenanceState({this.refreshingStorage = false});

  /// 正在重新扫描本地文件统计
  final bool refreshingStorage;

  GalleryMaintenanceState copyWith({bool? refreshingStorage}) =>
      GalleryMaintenanceState(
        refreshingStorage: refreshingStorage ?? this.refreshingStorage,
      );
}

/// 设置页的维护操作: 下载 / 标记已处理 / 清空数据
///
/// 页面只负责确认对话框与提示, 数据与文件的实际改动都在这里完成。
@riverpod
class GalleryMaintenance extends _$GalleryMaintenance {
  @override
  GalleryMaintenanceState build() => const GalleryMaintenanceState();

  /// 重新扫描本地文件统计, 并刷新数据库统计
  Future<void> refreshStorageStats() async {
    state = state.copyWith(refreshingStorage: true);
    try {
      await ref.read(galleryCachedStorageStatsProvider.notifier).refresh();
      ref.invalidate(galleryDbStatsProvider);
    } finally {
      state = state.copyWith(refreshingStorage: false);
    }
  }

  /// 下载一批媒体文件并刷新统计
  Future<void> downloadBatch(int limit) async {
    await ref
        .read(gallerySyncServiceProvider.notifier)
        .downloadBatch(limit: limit);
    ref.invalidate(galleryDbStatsProvider);
    ref.invalidate(galleryUploadStatsProvider);
    try {
      await ref.read(galleryCachedStorageStatsProvider.notifier).refresh();
    } catch (_) {}
  }

  /// 标记队列前段为已处理, 并清理其本地记录与文件
  Future<void> markProcessedAndClean() async {
    await ref.read(gallerySyncServiceProvider.notifier).markProcessedAndClean();
    ref.invalidate(galleryDbStatsProvider);
    ref.invalidate(galleryUploadStatsProvider);
    // 文件扫描较慢, 不阻塞页面
    unawaited(
      ref
          .read(galleryCachedStorageStatsProvider.notifier)
          .refresh()
          .catchError((_) {}),
    );
  }

  /// 清空数据库记录
  Future<void> clearDatabase() async {
    await ref.read(galleryDatabaseProvider).clearAllData();
    await _resetCursor();
    ref.invalidate(mediaAssetListProvider);
    ref.invalidate(tagTreeProvider);
    ref.invalidate(galleryDbStatsProvider);
    ref.invalidate(galleryUploadStatsProvider);
  }

  /// 清空本地媒体文件
  Future<void> clearFiles() async {
    await ref.read(galleryStorageProvider).clearAllFiles();
    try {
      await ref.read(galleryCachedStorageStatsProvider.notifier).refresh();
    } catch (_) {}
  }

  /// 清空数据库记录与本地文件
  Future<void> clearAll() async {
    await ref.read(galleryDatabaseProvider).clearAllData();
    await ref.read(galleryStorageProvider).clearAllFiles();
    await _resetCursor();
    ref.invalidate(mediaAssetListProvider);
    ref.invalidate(tagTreeProvider);
    ref.invalidate(galleryDbStatsProvider);
    ref.invalidate(galleryUploadStatsProvider);
    try {
      await ref.read(galleryCachedStorageStatsProvider.notifier).refresh();
    } catch (_) {}
  }

  /// 浏览位置与批次游标归零
  Future<void> _resetCursor() async {
    await ref.read(galleryModifiedCountProvider.notifier).reset();
    await ref.read(galleryCurrentIndexProvider.notifier).update(0);
  }
}
