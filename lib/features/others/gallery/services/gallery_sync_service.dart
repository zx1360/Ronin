import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/core/services/debug/logging_service.dart';
import 'package:torrid/core/services/network/api_client.dart';
import 'package:torrid/features/others/gallery/models/data_batch.dart';
import 'package:torrid/features/others/gallery/providers/gallery_providers.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

part 'gallery_sync_service.g.dart';

/// 同步状态
enum SyncStatus {
  idle,
  downloading,
  uploading,
  success,
  error,
}

/// 同步进度信息
class SyncProgress {
  final SyncStatus status;
  final int current;
  final int total;
  final String? message;
  final String? error;

  const SyncProgress({
    this.status = SyncStatus.idle,
    this.current = 0,
    this.total = 0,
    this.message,
    this.error,
  });

  double get progress => total > 0 ? current / total : 0;

  SyncProgress copyWith({
    SyncStatus? status,
    int? current,
    int? total,
    String? message,
    String? error,
  }) {
    return SyncProgress(
      status: status ?? this.status,
      current: current ?? this.current,
      total: total ?? this.total,
      message: message ?? this.message,
      error: error,
    );
  }
}

/// Gallery 同步服务 Provider
@riverpod
class GallerySyncService extends _$GallerySyncService {
  CancelToken? _cancelToken;

  @override
  SyncProgress build() {
    ref.onDispose(() {
      _cancelToken?.cancel('disposed');
    });
    return const SyncProgress();
  }

  /// 取消当前操作
  void cancel() {
    _cancelToken?.cancel('用户取消');
    _cancelToken = null;
    state = const SyncProgress(status: SyncStatus.idle, message: '已取消');
  }

  /// 下载一批媒体文件
  /// 1. 获取 batch 数据 (媒体信息 + tags + links)
  /// 2. 存储数据到本地数据库
  /// 3. 下载媒体文件 (原图 + 缩略图 + 预览图)
  Future<bool> downloadBatch({int limit = 50}) async {
    if (state.status == SyncStatus.downloading ||
        state.status == SyncStatus.uploading) {
      return false;
    }

    _cancelToken = CancelToken();
    final db = ref.read(galleryDatabaseProvider);
    final storage = ref.read(galleryStorageProvider);
    final apiClient = ref.read(apiClientManagerProvider);

    try {
      // 1. 获取当前本地记录数作为 offset
      final offset = await db.getMediaAssetCount();
      
      state = SyncProgress(
        status: SyncStatus.downloading,
        message: '正在获取数据...',
        current: 0,
        total: 0,
      );

      // 2. 请求 batch 数据
      final response = await apiClient.get(
        '/api/gallery/batch',
        queryParams: {'limit': limit, 'offset': offset},
        cancelToken: _cancelToken,
      );

      if (response.statusCode != 200) {
        throw Exception('服务器响应错误: ${response.statusCode}');
      }

      final batchData = BatchResponse.fromJson(response.data);
      final assets = batchData.medias;
      final tags = batchData.tags;
      final links = batchData.links;

      if (assets.isEmpty) {
        state = const SyncProgress(
          status: SyncStatus.success,
          message: '没有新的媒体文件',
        );
        return true;
      }

      // 3. 保存数据到数据库
      state = state.copyWith(message: '正在保存数据...');
      
      await db.upsertMediaAssets(assets);
      if (tags.isNotEmpty) {
        await db.replaceAllTags(tags);
      }
      if (links.isNotEmpty) {
        await db.upsertMediaTagLinks(links);
      }

      // 4. 下载媒体文件
      final totalFiles = assets.length * 3; // 每个 asset 有3个文件
      int downloadedFiles = 0;

      state = state.copyWith(
        message: '正在下载文件...',
        total: totalFiles,
      );

      // 并发下载控制
      const maxConcurrent = 4;
      final downloadTasks = <Future>[];

      for (final asset in assets) {
        if (_cancelToken?.isCancelled ?? false) {
          throw Exception('下载已取消');
        }

        // 下载原图
        downloadTasks.add(_downloadFile(
          apiClient: apiClient,
          path: '/api/gallery/${asset.id}/file',
          saveFn: (bytes) => storage.saveMediaFile(
            serverPath: asset.filePath,
            bytes: bytes,
          ),
          onComplete: () {
            downloadedFiles++;
            state = state.copyWith(current: downloadedFiles);
          },
        ));

        // 下载缩略图
        if (asset.thumbPath != null) {
          downloadTasks.add(_downloadFile(
            apiClient: apiClient,
            path: '/api/gallery/${asset.id}/thumb',
            saveFn: (bytes) => storage.saveThumbFile(
              serverPath: asset.thumbPath!,
              bytes: bytes,
            ),
            onComplete: () {
              downloadedFiles++;
              state = state.copyWith(current: downloadedFiles);
            },
          ));
        } else {
          downloadedFiles++;
        }

        // 下载预览图
        if (asset.previewPath != null) {
          downloadTasks.add(_downloadFile(
            apiClient: apiClient,
            path: '/api/gallery/${asset.id}/preview',
            saveFn: (bytes) => storage.savePreviewFile(
              serverPath: asset.previewPath!,
              bytes: bytes,
            ),
            onComplete: () {
              downloadedFiles++;
              state = state.copyWith(current: downloadedFiles);
            },
          ));
        } else {
          downloadedFiles++;
        }

        // 控制并发数
        if (downloadTasks.length >= maxConcurrent) {
          await Future.wait(downloadTasks);
          downloadTasks.clear();
        }
      }

      // 等待剩余任务完成
      if (downloadTasks.isNotEmpty) {
        await Future.wait(downloadTasks);
      }

      // 5. 刷新数据
      ref.invalidate(mediaAssetListProvider);

      state = SyncProgress(
        status: SyncStatus.success,
        message: '成功下载 ${assets.length} 个文件',
        current: totalFiles,
        total: totalFiles,
      );

      AppLogger().info('Gallery 下载完成: ${assets.length} 个文件');
      return true;
    } on DioException catch (e) {
      final errorMsg = e.type == DioExceptionType.cancel
          ? '下载已取消'
          : '网络错误: ${e.message}';
      state = SyncProgress(status: SyncStatus.error, error: errorMsg);
      AppLogger().error('Gallery 下载失败: $errorMsg');
      return false;
    } catch (e) {
      state = SyncProgress(status: SyncStatus.error, error: e.toString());
      AppLogger().error('Gallery 下载失败: $e');
      return false;
    } finally {
      _cancelToken = null;
    }
  }

  /// 下载单个文件
  Future<void> _downloadFile({
    required ApiClient apiClient,
    required String path,
    required Future<dynamic> Function(List<int> bytes) saveFn,
    required VoidCallback onComplete,
  }) async {
    try {
      final response = await apiClient.getBinary(
        path,
        cancelToken: _cancelToken,
      );
      
      if (response.data != null) {
        await saveFn(response.data!);
      }
    } catch (e) {
      AppLogger().error('下载文件失败 $path: $e');
      // 单个文件失败不影响整体
    } finally {
      onComplete();
    }
  }

  /// 上传本地数据到服务端
  /// 上传全部本地数据，然后清理本地
  Future<bool> uploadData() async {
    if (state.status == SyncStatus.downloading ||
        state.status == SyncStatus.uploading) {
      return false;
    }

    _cancelToken = CancelToken();
    final db = ref.read(galleryDatabaseProvider);
    final storage = ref.read(galleryStorageProvider);
    final apiClient = ref.read(apiClientManagerProvider);

    try {
      state = const SyncProgress(
        status: SyncStatus.uploading,
        message: '正在准备数据...',
      );

      // 1. 获取本地数据
      final data = await db.getDataForUpload();
      
      if (data.assets.isEmpty) {
        state = const SyncProgress(
          status: SyncStatus.success,
          message: '没有数据需要上传',
        );
        return true;
      }

      state = state.copyWith(
        message: '正在上传数据...',
        total: data.assets.length,
      );

      // 2. 构建上传数据
      final uploadPayload = BatchResponse(
        medias: data.assets,
        tags: data.tags,
        links: data.links,
      );

      // 3. 发送到服务端
      final response = await apiClient.post(
        '/api/gallery/push',
        jsonData: {'data': jsonEncode(uploadPayload.toJson())},
        cancelToken: _cancelToken,
      );

      if (response.statusCode != 200) {
        throw Exception('服务器响应错误: ${response.statusCode}');
      }

      state = state.copyWith(
        current: data.assets.length,
        message: '正在清理本地数据...',
      );

      // 4. 删除本地文件
      for (final asset in data.assets) {
        await storage.deleteMediaFiles(
          filePath: asset.filePath,
          thumbPath: asset.thumbPath,
          previewPath: asset.previewPath,
        );
      }

      // 5. 清理空目录
      await storage.cleanupEmptyDirectories();

      // 6. 清空数据库
      await db.clearAllData();

      // 7. 重置状态
      await ref.read(galleryModifiedCountProvider.notifier).reset();
      await ref.read(galleryCurrentIndexProvider.notifier).update(0);
      
      // 8. 刷新数据
      ref.invalidate(mediaAssetListProvider);
      ref.invalidate(tagTreeProvider);

      state = SyncProgress(
        status: SyncStatus.success,
        message: '成功上传 ${data.assets.length} 条记录',
        current: data.assets.length,
        total: data.assets.length,
      );

      AppLogger().info('Gallery 上传完成: ${data.assets.length} 条记录');
      return true;
    } on DioException catch (e) {
      final errorMsg = e.type == DioExceptionType.cancel
          ? '上传已取消'
          : '网络错误: ${e.message}';
      state = SyncProgress(status: SyncStatus.error, error: errorMsg);
      AppLogger().error('Gallery 上传失败: $errorMsg');
      return false;
    } catch (e) {
      state = SyncProgress(status: SyncStatus.error, error: e.toString());
      AppLogger().error('Gallery 上传失败: $e');
      return false;
    } finally {
      _cancelToken = null;
    }
  }

  /// 重置状态
  void resetStatus() {
    state = const SyncProgress();
  }
}

/// 待上传数据统计 Provider
/// 按照 modified_count 计算需要上传的记录：
/// - media_assets: sync_count <= modified_count 的记录
/// - tags: 全量
/// - media_tag_links: 与涉及到的 media_assets 关联的记录
@riverpod
Future<UploadStats> galleryUploadStats(GalleryUploadStatsRef ref) async {
  final db = ref.watch(galleryDatabaseProvider);
  final modifiedCount = ref.watch(galleryModifiedCountProvider);
  
  // 获取需要上传的 media_assets 数量
  final mediaCount = await db.getModifiedMediaAssetCount(modifiedCount);
  
  // tags 全量上传
  final tagCount = await db.getTagCount();
  
  // 获取涉及到的 media_ids，计算关联的 links 数量
  final mediaIds = await db.getModifiedMediaAssetIds(modifiedCount);
  final linkCount = await db.getMediaTagLinkCountForMediaIds(mediaIds);
  
  return UploadStats(
    mediaCount: mediaCount,
    tagCount: tagCount,
    linkCount: linkCount,
  );
}

/// 待上传统计
class UploadStats {
  final int mediaCount;
  final int tagCount;
  final int linkCount;

  const UploadStats({
    required this.mediaCount,
    required this.tagCount,
    required this.linkCount,
  });

  bool get hasData => mediaCount > 0;
}
