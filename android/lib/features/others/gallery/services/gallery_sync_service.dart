import 'dart:io';
import 'dart:isolate';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:torrid/core/services/debug/logging_service.dart';
import 'package:torrid/core/services/network/api_client.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/providers/gallery_providers.dart';
import 'package:torrid/features/others/gallery/services/gallery_database_service.dart';
import 'package:torrid/features/others/gallery/services/gallery_storage_service.dart';

part 'gallery_sync_service.g.dart';

/// 同步状态
enum SyncStatus { idle, downloading, uploading, success, error }

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
    if (state.status != SyncStatus.downloading) return;
    _cancelToken?.cancel('用户取消');
  }

  /// 下载一批媒体记录及缩略图、预览图。
  Future<bool> downloadBatch({int limit = 50}) async {
    if (state.status == SyncStatus.downloading ||
        state.status == SyncStatus.uploading) {
      return false;
    }

    final keepAlive = ref.keepAlive();
    _cancelToken = CancelToken();
    final db = ref.read(galleryDatabaseProvider);
    final storage = ref.read(galleryStorageProvider);
    final buffer = ref.read(galleryWriteBufferProvider);
    var confirmedWrites = false;

    try {
      state = SyncProgress(
        status: SyncStatus.downloading,
        message: '正在获取数据...',
        current: 0,
        total: 0,
      );

      final api = await buffer.confirmAndLock();
      final apiClient = api.client;
      confirmedWrites = true;
      if ((await db.operations()).any((op) => op.kind == 'processed')) {
        throw StateError('请先重试完成上次的标记已处理');
      }
      final cached = await db.getMediaAssets(includeGroupMembers: true);
      final cachedIds = cached.map((asset) => asset.id).toSet();

      // 2. 请求 batch 数据（携带筛选/排序参数）
      final mimeFilter = ref.read(galleryDownloadMimeFilterProvider);
      final sortBy = ref.read(galleryDownloadSortByProvider);
      final sortOrder = ref.read(galleryDownloadSortOrderProvider);
      final filterYear = ref.read(galleryDownloadYearProvider);
      final filterMonth = ref.read(galleryDownloadMonthProvider);
      final filterDay = ref.read(galleryDownloadDayProvider);
      final secondarySort = ref.read(galleryDownloadSecondarySortProvider);

      final queryParams = <String, dynamic>{};
      if (mimeFilter.isNotEmpty) queryParams['mime_type'] = mimeFilter;
      if (sortBy.isNotEmpty) queryParams['sort_by'] = sortBy;
      if (sortOrder.isNotEmpty) queryParams['sort_order'] = sortOrder;
      if (filterYear > 0) queryParams['year'] = filterYear;
      if (filterMonth > 0) queryParams['month'] = filterMonth;
      if (filterDay > 0) queryParams['day'] = filterDay;
      if (secondarySort.isNotEmpty) {
        queryParams['secondary_sort'] = secondarySort;
      }

      final batchData = await api.fetchUncachedBatch(
        limit: limit,
        cachedIds: cachedIds,
        filters: queryParams,
        cancelToken: _cancelToken,
      );
      final assets = batchData.medias;
      if (_cancelToken?.isCancelled == true) throw _cancelToken!.cancelError!;
      await db.storeBatch(batchData);
      // 重试只补缺失文件，不覆盖已有工作副本及标注。
      final files = <({String route, String path, bool thumb})>[];
      for (final asset in [...cached, ...assets]) {
        if (_cancelToken!.isCancelled) throw _cancelToken!.cancelError!;
        if (asset.isDeleted) continue;
        if (asset.thumbPath != null &&
            await storage.getThumbFile(asset.thumbPath!) == null) {
          files.add((
            route: '/API/gallery/${asset.id}/thumb',
            path: asset.thumbPath!,
            thumb: true,
          ));
        }
        if (asset.previewPath != null &&
            await storage.getPreviewFile(asset.previewPath!) == null) {
          files.add((
            route: '/API/gallery/${asset.id}/preview',
            path: asset.previewPath!,
            thumb: false,
          ));
        }
      }
      var completed = 0;
      var failed = 0;
      state = state.copyWith(message: '正在补齐缓存文件...', total: files.length);
      for (var start = 0; start < files.length; start += 4) {
        if (_cancelToken!.isCancelled) throw _cancelToken!.cancelError!;
        final results = await Future.wait(
          files
              .skip(start)
              .take(4)
              .map(
                (file) => _downloadFile(
                  apiClient: apiClient,
                  path: api.path(file.route),
                  saveFn: (bytes) => file.thumb
                      ? storage.saveThumbFile(
                          serverPath: file.path,
                          bytes: bytes,
                        )
                      : storage.savePreviewFile(
                          serverPath: file.path,
                          bytes: bytes,
                        ),
                  onComplete: () =>
                      state = state.copyWith(current: ++completed),
                ),
              ),
        );
        failed += results.where((success) => !success).length;
      }
      if (_cancelToken!.isCancelled) throw _cancelToken!.cancelError!;
      if (files.isNotEmpty) {
        ref.read(galleryFilesRevisionProvider.notifier).state++;
      }
      if (failed > 0) {
        state = SyncProgress(
          status: SyncStatus.error,
          error: '$failed 个文件下载失败，请重试下载以补齐缓存',
          current: completed,
          total: files.length,
        );
        return false;
      }
      state = SyncProgress(
        status: SyncStatus.success,
        message: assets.isEmpty && files.isEmpty
            ? '没有新的媒体文件，缓存已完整'
            : '新增 ${assets.length} 条媒体，补齐 ${files.length} 个缓存文件',
        current: completed,
        total: files.length,
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
      if (confirmedWrites) buffer.unlock();
      _cancelToken = null;
      keepAlive.close();
    }
  }

  /// 下载单个文件
  Future<bool> _downloadFile({
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

      if (response.data?.isNotEmpty != true) {
        throw const FormatException('文件内容为空');
      }
      await saveFn(response.data!);
      return true;
    } catch (e) {
      AppLogger().error('下载文件失败 $path: $e');
      return false;
    } finally {
      onComplete();
    }
  }

  /// 标记已处理并清理本地缓存
  ///
  /// 先回传并逐项校验本地操作，再推进服务端游标和清理本机记录。
  /// 1. 把队列前段 `0..[processedUpperIndex]` 的媒体在服务端 `sync_count + 1`
  ///    （批次处理游标, 使已处理媒体排到队尾, 下次下载取到的就是未处理的）;
  /// 2. 删除这批媒体的本地记录与缩略图/预览图, 腾出空间下载下一批.
  Future<bool> markProcessedAndClean() async {
    if (state.status == SyncStatus.downloading ||
        state.status == SyncStatus.uploading) {
      return false;
    }

    final keepAlive = ref.keepAlive();
    _cancelToken = CancelToken();
    final db = ref.read(galleryDatabaseProvider);
    final storage = ref.read(galleryStorageProvider);
    final buffer = ref.read(galleryWriteBufferProvider);
    var confirmedWrites = false;

    try {
      state = const SyncProgress(
        status: SyncStatus.uploading,
        message: '正在准备数据...',
      );

      state = state.copyWith(message: '正在回传并校验操作...');
      final api = await buffer.confirmAndLock();
      confirmedWrites = true;

      final operations = await db.operations();
      final saved = operations
          .where((op) => op.kind == 'processed')
          .firstOrNull;
      final processedAssets = saved == null
          ? await db.getProcessedAssets()
          : [
              for (final id in (saved.body['media_ids'] as List).cast<String>())
                if (await db.getMediaAssetById(id) case final asset?) asset,
            ];
      if (saved != null &&
          processedAssets.length != (saved.body['media_ids'] as List).length) {
        throw StateError('本地待回传批次不完整，已保留操作记录');
      }
      if (processedAssets.isEmpty) {
        await db.deleteProcessedData([]);
        state = const SyncProgress(
          status: SyncStatus.success,
          message: '没有需要标记的媒体',
        );
        return true;
      }

      state = state.copyWith(
        message: '正在标记已处理...',
        total: processedAssets.length,
      );

      final mediaIds = processedAssets.map((a) => a.id).toList();

      final completion =
          saved ??
          await db.recordOperation('processed', {
            'media_ids': mediaIds,
            'mark_processed': true,
            'request_id': const Uuid().v4(),
          });
      await api.sendOperation(completion);

      // 3. 删除本地记录与文件
      await db.deleteProcessedData(mediaIds, confirmedSequence: completion.seq);
      ref.invalidate(galleryServerOverviewProvider);

      await _deleteLocalFiles(processedAssets, storage);

      state = SyncProgress(
        status: SyncStatus.success,
        message: '已处理 ${mediaIds.length} 条记录',
        current: mediaIds.length,
        total: mediaIds.length,
      );

      AppLogger().info('Gallery 标记已处理: ${mediaIds.length} 条记录');
      return true;
    } on ApiException catch (e) {
      state = SyncProgress(status: SyncStatus.error, error: e.message);
      AppLogger().error('Gallery 标记已处理失败: ${e.message}');
      return false;
    } on DioException catch (e) {
      final errorMsg = e.type == DioExceptionType.cancel
          ? '操作已取消'
          : '网络错误: ${e.message}';
      state = SyncProgress(status: SyncStatus.error, error: errorMsg);
      AppLogger().error('Gallery 标记已处理失败: $errorMsg');
      return false;
    } catch (e) {
      state = SyncProgress(status: SyncStatus.error, error: e.toString());
      AppLogger().error('Gallery 标记已处理失败: $e');
      return false;
    } finally {
      if (confirmedWrites) buffer.unlock();
      _cancelToken = null;
      keepAlive.close();
    }
  }

  /// 重置状态
  void resetStatus() {
    state = const SyncProgress();
  }

  /// 后台删除已处理媒体的本地缩略图和预览图
  /// 在主 isolate 中解析路径后，在后台 Isolate 中执行文件删除
  Future<void> _deleteLocalFiles(
    List<MediaAsset> assets,
    GalleryStorageService storage,
  ) async {
    if (assets.isEmpty) return;
    // 先解析为本地绝对路径（主 isolate），再传给后台 isolate 删除
    try {
      final thumbResolved = <String>[];
      final previewResolved = <String>[];
      for (final asset in assets) {
        if (asset.thumbPath != null) {
          thumbResolved.add(await storage.getLocalThumbPath(asset.thumbPath!));
        }
        if (asset.previewPath != null) {
          previewResolved.add(
            await storage.getLocalPreviewPath(asset.previewPath!),
          );
        }
      }
      // 在后台 isolate 中执行纯文件 I/O，不阻塞 UI
      if (thumbResolved.isNotEmpty || previewResolved.isNotEmpty) {
        await Isolate.run(
          () => _deleteFilesInIsolate(thumbResolved, previewResolved),
        );
      }
    } catch (error) {
      AppLogger().error('Gallery 本地缓存文件清理失败: $error');
    }
  }
}

@riverpod
Stream<({int mediaCount, int deletedCount})> galleryProcessedStats(Ref ref) =>
    ref.watch(galleryDatabaseProvider).watchProcessedStats();

/// 在独立 Isolate 中删除已处理媒体的本地文件
/// 接收已解析的本地绝对路径，执行纯文件 I/O
Future<void> _deleteFilesInIsolate(
  List<String> thumbResolvedPaths,
  List<String> previewResolvedPaths,
) async {
  for (final path in thumbResolvedPaths) {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
  for (final path in previewResolvedPaths) {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  // 清理空目录
  if (thumbResolvedPaths.isNotEmpty) {
    try {
      final firstPath = thumbResolvedPaths.first;
      // 向上找到 gallery 根目录
      final parts = firstPath.split(Platform.pathSeparator);
      final galleryIdx = parts.indexWhere((p) => p == 'gallery');
      if (galleryIdx >= 0) {
        final galleryRoot = parts
            .take(galleryIdx + 1)
            .join(Platform.pathSeparator);
        await _cleanupEmptyDirs(Directory(galleryRoot));
      }
    } catch (_) {}
  }
}

Future<void> _cleanupEmptyDirs(Directory dir) async {
  if (!await dir.exists()) return;
  final entities = dir.listSync(recursive: false);
  for (final entity in entities) {
    if (entity is Directory) {
      await _cleanupEmptyDirs(entity);
      if (entity.listSync().isEmpty) {
        try {
          await entity.delete();
        } catch (_) {}
      }
    }
  }
}
