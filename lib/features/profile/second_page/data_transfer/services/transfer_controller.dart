/// 数据传输控制器
///
/// 统一管理数据同步和备份操作，支持进度跟踪、并发传输、重试机制。
///
/// 使用 Notifier 模式避免 Provider 初始化时修改其他 Provider 的问题。
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/booklet/providers/providers.dart';
import 'package:torrid/features/essay/providers/essay_notifier_provider.dart';
import 'package:torrid/features/profile/second_page/data_transfer/models/transfer_progress.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';
import 'package:torrid/core/services/debug/logging_service.dart';
import 'package:torrid/core/services/io/io_service.dart';

part 'transfer_controller.g.dart';

/// 传输配置常量
const int _maxConcurrent = 5;
const int _maxRetries = 3;
const Duration _retryDelay = Duration(milliseconds: 300);
const Duration _batchDelay = Duration(milliseconds: 50);

/// 数据传输控制器
///
/// 提供同步和备份功能，管理传输状态。
@riverpod
class TransferController extends _$TransferController {
  @override
  TransferProgress build() => TransferProgress.idle();

  // ===========================================================================
  // 公开方法 - 执行传输操作
  // ===========================================================================

  /// 执行传输操作
  Future<TransferResult> execute({
    required TransferType type,
    required TransferTarget target,
  }) async {
    // 防止重复操作
    if (state.isInProgress) {
      return TransferResult.failed(message: '有传输任务正在进行中');
    }

    return switch (type) {
      TransferType.sync => _executeSync(target),
      TransferType.backup => _executeBackup(target),
    };
  }

  /// 执行同步所有
  Future<TransferResult> syncAll() async {
    if (state.isInProgress) {
      return TransferResult.failed(message: '有传输任务正在进行中');
    }

    final startTime = DateTime.now();
    final results = <TransferResult>[];

    // 同步打卡
    results.add(await _syncBooklet());

    // 同步随笔
    results.add(await _syncEssay());

    return _combineResults(results, TransferType.sync, startTime);
  }

  /// 执行备份所有
  Future<TransferResult> backupAll() async {
    if (state.isInProgress) {
      return TransferResult.failed(message: '有传输任务正在进行中');
    }

    final startTime = DateTime.now();
    final results = <TransferResult>[];

    // 备份打卡
    results.add(await _backupBooklet());

    // 备份随笔
    results.add(await _backupEssay());

    return _combineResults(results, TransferType.backup, startTime);
  }

  /// 重置状态
  void reset() {
    state = TransferProgress.idle();
  }

  // ===========================================================================
  // 私有方法 - 同步操作
  // ===========================================================================

  Future<TransferResult> _executeSync(TransferTarget target) {
    return switch (target) {
      TransferTarget.all => throw StateError('Use syncAll() for all targets'),
      TransferTarget.booklet => _syncBooklet(),
      TransferTarget.essay => _syncEssay(),
    };
  }

  Future<TransferResult> _syncBooklet() async {
    final startTime = DateTime.now();

    _updateState(
      type: TransferType.sync,
      target: TransferTarget.booklet,
      status: TransferStatus.preparing,
      message: '正在获取打卡数据...',
    );

    try {
      // 1. 获取数据
      final resp = await ref.read(
        fetcherProvider(path: "/api/user-data/sync/booklet").future,
      );
      if (resp == null || resp.statusCode != 200) {
        throw Exception("获取打卡数据失败");
      }

      // 2. 同步数据
      final data = resp.data;
      await ref.read(routineServiceProvider.notifier).syncData(data);

      // 3. 收集图片URL
      final imageUrls = _extractBookletImageUrls(data);

      // 4. 下载图片
      if (imageUrls.isNotEmpty) {
        final result = await _downloadImages(
          urls: imageUrls,
          relativeDir: "img_storage/booklet",
        );

        if (!result.success) {
          _completeTransfer(false, result.message, result.failedItems);
          return result._withElapsed(startTime);
        }
      }

      _completeTransfer(true, '打卡数据同步完成');
      return TransferResult.success(
        message: '打卡数据同步成功',
        successCount: imageUrls.length,
        elapsed: DateTime.now().difference(startTime),
      );
    } catch (e) {
      AppLogger().error("同步打卡数据出错: $e");
      _completeTransfer(false, '打卡同步失败', null, e.toString());
      return TransferResult.failed(
        message: '打卡同步失败: $e',
        elapsed: DateTime.now().difference(startTime),
      );
    }
  }

  Future<TransferResult> _syncEssay() async {
    final startTime = DateTime.now();

    _updateState(
      type: TransferType.sync,
      target: TransferTarget.essay,
      status: TransferStatus.preparing,
      message: '正在获取随笔数据...',
    );

    try {
      // 1. 获取数据
      final resp = await ref.read(
        fetcherProvider(path: "/api/user-data/sync/essay").future,
      );
      if (resp == null || resp.statusCode != 200) {
        throw Exception("获取随笔数据失败");
      }

      // 2. 同步数据
      final data = resp.data;
      await ref.read(essayServiceProvider.notifier).syncData(data);

      // 3. 收集图片URL
      final imageUrls = _extractEssayImageUrls(data);

      // 4. 下载图片
      if (imageUrls.isNotEmpty) {
        final result = await _downloadImages(
          urls: imageUrls,
          relativeDir: "img_storage/essay",
        );

        if (!result.success) {
          _completeTransfer(false, result.message, result.failedItems);
          return result._withElapsed(startTime);
        }
      }

      _completeTransfer(true, '随笔数据同步完成');
      return TransferResult.success(
        message: '随笔数据同步成功',
        successCount: imageUrls.length,
        elapsed: DateTime.now().difference(startTime),
      );
    } catch (e) {
      AppLogger().error("同步随笔数据出错: $e");
      _completeTransfer(false, '随笔同步失败', null, e.toString());
      return TransferResult.failed(
        message: '随笔同步失败: $e',
        elapsed: DateTime.now().difference(startTime),
      );
    }
  }

  // ===========================================================================
  // 私有方法 - 备份操作
  // ===========================================================================

  Future<TransferResult> _executeBackup(TransferTarget target) {
    return switch (target) {
      TransferTarget.all => throw StateError('Use backupAll() for all targets'),
      TransferTarget.booklet => _backupBooklet(),
      TransferTarget.essay => _backupEssay(),
    };
  }

  Future<TransferResult> _backupBooklet() async {
    final startTime = DateTime.now();

    try {
      final notifier = ref.read(routineServiceProvider.notifier);
      final data = notifier.packUp();

      // 获取文件列表
      final externalDir = await IoService.externalStorageDir;
      final imgPaths = notifier.getImgsPath();
      final files = imgPaths
          .map((path) => File("${externalDir.path}/$path"))
          .where((f) => f.existsSync())
          .toList();

      _updateState(
        type: TransferType.backup,
        target: TransferTarget.booklet,
        status: TransferStatus.preparing,
        total: files.length + 1,
        message: '正在备份打卡数据...',
      );

      final result = await _uploadData(
        path: "/api/user-data/backup/booklet",
        jsonData: data,
        files: files,
      );

      _completeTransfer(result.success, result.message);
      return result._withElapsed(startTime);
    } catch (e) {
      AppLogger().error("备份打卡数据出错: $e");
      _completeTransfer(false, '打卡备份失败', null, e.toString());
      return TransferResult.failed(
        message: '打卡备份失败: $e',
        elapsed: DateTime.now().difference(startTime),
      );
    }
  }

  Future<TransferResult> _backupEssay() async {
    final startTime = DateTime.now();

    try {
      final notifier = ref.read(essayServiceProvider.notifier);
      final data = notifier.packUp();

      // 获取文件列表
      final externalDir = await IoService.externalStorageDir;
      final imgPaths = notifier.getImgsPath();
      final files = imgPaths
          .map((path) => File("${externalDir.path}/$path"))
          .where((f) => f.existsSync())
          .toList();

      _updateState(
        type: TransferType.backup,
        target: TransferTarget.essay,
        status: TransferStatus.preparing,
        total: files.length + 1,
        message: '正在备份随笔数据...',
      );

      final result = await _uploadData(
        path: "/api/user-data/backup/essay",
        jsonData: data,
        files: files,
      );

      _completeTransfer(result.success, result.message);
      return result._withElapsed(startTime);
    } catch (e) {
      AppLogger().error("备份随笔数据出错: $e");
      _completeTransfer(false, '随笔备份失败', null, e.toString());
      return TransferResult.failed(
        message: '随笔备份失败: $e',
        elapsed: DateTime.now().difference(startTime),
      );
    }
  }

  // ===========================================================================
  // 私有方法 - 图片下载
  // ===========================================================================

  Future<TransferResult> _downloadImages({
    required List<String> urls,
    required String relativeDir,
  }) async {
    if (urls.isEmpty) {
      return TransferResult.success(message: '无图片需要下载');
    }

    _updateProgress(
      total: urls.length,
      message: '正在下载图片...',
      status: TransferStatus.inProgress,
    );

    // 准备目录
    await IoService.clearSpecificDirectory(relativeDir);
    final externalDir = await IoService.externalStorageDir;
    final targetDir = p.join(externalDir.path, relativeDir);
    final directory = Directory(targetDir);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    // 分批下载
    final failedItems = <FailedItem>[];
    int successCount = 0;

    final batches = _createBatches(urls, _maxConcurrent);
    for (final batch in batches) {
      final results = await Future.wait(
        batch.map((url) => _downloadSingleImage(url, targetDir)),
      );

      for (final result in results) {
        if (result.success) {
          successCount++;
        } else {
          failedItems.add(result.failedItem!);
        }
        _incrementProgress(p.basename(result.url));
      }

      await Future.delayed(_batchDelay);
    }

    // 重试失败项
    if (failedItems.isNotEmpty) {
      _updateProgress(status: TransferStatus.retrying, message: '正在重试失败项...');
      final stillFailed = await _retryDownloads(failedItems, targetDir);
      successCount += failedItems.length - stillFailed.length;

      if (stillFailed.isNotEmpty) {
        return TransferResult.failed(
          message: '下载完成，但有${stillFailed.length}个文件失败',
          successCount: successCount,
          failedCount: stillFailed.length,
          failedItems: stillFailed,
        );
      }
    }

    return TransferResult.success(
      message: '图片下载完成',
      successCount: successCount,
    );
  }

  Future<_DownloadResult> _downloadSingleImage(
    String url,
    String targetDir,
  ) async {
    try {
      final response = await ref.read(
        bytesFetcherProvider(path: "/static/$url").future,
      );
      if (response == null || response.statusCode != 200) {
        throw Exception('状态码: ${response?.statusCode}');
      }

      final Uint8List imageData = response.data!;
      final fileName = p.basename(url);
      final savePath = p.join(targetDir, fileName);
      await File(savePath).writeAsBytes(imageData);

      return _DownloadResult(url: url, success: true);
    } catch (e) {
      return _DownloadResult(
        url: url,
        success: false,
        failedItem: FailedItem(
          name: p.basename(url),
          path: url,
          error: e.toString(),
        ),
      );
    }
  }

  Future<List<FailedItem>> _retryDownloads(
    List<FailedItem> failedItems,
    String targetDir,
  ) async {
    final stillFailed = <FailedItem>[];

    for (final item in failedItems) {
      bool success = false;
      int retryCount = 0;
      String lastError = item.error;

      while (!success && retryCount < _maxRetries) {
        retryCount++;
        await Future.delayed(_retryDelay);

        try {
          final response = await ref.read(
            bytesFetcherProvider(path: "/static/${item.path}").future,
          );
          if (response != null && response.statusCode == 200) {
            await File(
              p.join(targetDir, item.name),
            ).writeAsBytes(response.data!);
            success = true;
            AppLogger().info("重试成功: ${item.name}");
          }
        } catch (e) {
          lastError = e.toString();
          AppLogger().warning("重试失败 ($retryCount/$_maxRetries): ${item.name}");
        }
      }

      if (!success) {
        stillFailed.add(
          item.copyWith(retryCount: retryCount, error: lastError),
        );
      }
    }

    return stillFailed;
  }

  // ===========================================================================
  // 私有方法 - 数据上传
  // ===========================================================================

  Future<TransferResult> _uploadData({
    required String path,
    required Map<String, dynamic> jsonData,
    required List<File> files,
  }) async {
    try {
      _updateProgress(
        current: 0,
        message: '正在上传数据...',
        status: TransferStatus.inProgress,
      );

      int uploadedCount = 0;
      final resp = await ref.read(
        senderProvider(
          path: path,
          jsonData: jsonData,
          files: files,
          onSendProgress: (sent, total) {
            if (total > 0) {
              final progress = (sent / total * files.length).round();
              if (progress > uploadedCount) {
                uploadedCount = progress;
                _updateProgress(
                  current: uploadedCount,
                  currentMessage: '已上传 $uploadedCount/${files.length}',
                );
              }
            }
          },
        ).future,
      );

      if (resp?.statusCode == 200) {
        return TransferResult.success(
          message: '上传成功',
          successCount: files.length + 1,
        );
      }
      return TransferResult.failed(message: '上传失败: 状态码 ${resp?.statusCode}');
    } catch (e) {
      return TransferResult.failed(message: '上传出错: $e');
    }
  }

  // ===========================================================================
  // 私有方法 - 状态管理
  // ===========================================================================

  void _updateState({
    required TransferType type,
    required TransferTarget target,
    required TransferStatus status,
    int total = 0,
    String message = '',
  }) {
    state = TransferProgress(
      type: type,
      target: target,
      status: status,
      total: total,
      current: 0,
      message: message,
      startTime: DateTime.now(),
    );
  }

  void _updateProgress({
    int? total,
    int? current,
    String? currentMessage,
    String? message,
    TransferStatus? status,
  }) {
    state = state.copyWith(
      total: total,
      current: current,
      currentMessage: currentMessage,
      message: message,
      status: status,
    );
  }

  void _incrementProgress(String currentMessage) {
    state = state.copyWith(
      current: state.current + 1,
      currentMessage: currentMessage,
      status: state.status == TransferStatus.preparing
          ? TransferStatus.inProgress
          : null,
    );
  }

  void _completeTransfer(
    bool success,
    String message, [
    List<FailedItem>? failedItems,
    String? errorMessage,
  ]) {
    state = state.copyWith(
      status: success ? TransferStatus.success : TransferStatus.failed,
      message: message,
      failedItems: failedItems,
      errorMessage: errorMessage,
      endTime: DateTime.now(),
    );
  }

  // ===========================================================================
  // 辅助方法
  // ===========================================================================

  List<String> _extractBookletImageUrls(dynamic data) {
    final urls = <String>[];
    final styles = data['styles'] as List? ?? [];
    for (final style in styles) {
      final tasks = style['tasks'] as List? ?? [];
      for (final task in tasks) {
        final image = task['image'] as String?;
        if (image != null && image.isNotEmpty) {
          urls.add(image);
        }
      }
    }
    return urls;
  }

  List<String> _extractEssayImageUrls(dynamic data) {
    final urls = <String>[];
    final essays = data['essays'] as List? ?? [];
    for (final essay in essays) {
      final imgs = essay['imgs'] as List? ?? [];
      for (final img in imgs) {
        if (img != null && img.toString().isNotEmpty) {
          urls.add(img.toString());
        }
      }
    }
    return urls;
  }

  List<List<T>> _createBatches<T>(List<T> items, int batchSize) {
    final batches = <List<T>>[];
    for (int i = 0; i < items.length; i += batchSize) {
      final end = (i + batchSize > items.length) ? items.length : i + batchSize;
      batches.add(items.sublist(i, end));
    }
    return batches;
  }

  TransferResult _combineResults(
    List<TransferResult> results,
    TransferType type,
    DateTime startTime,
  ) {
    final totalSuccess = results.fold(0, (sum, r) => sum + r.successCount);
    final totalFailed = results.fold(0, (sum, r) => sum + r.failedCount);
    final allFailedItems = results.expand((r) => r.failedItems).toList();
    final allSuccess = results.every((r) => r.success);
    final typeName = type == TransferType.sync ? '同步' : '备份';

    _completeTransfer(
      allSuccess,
      allSuccess ? '全部数据$typeName成功' : '$typeName完成，部分失败',
      allFailedItems,
    );

    return TransferResult(
      success: allSuccess,
      message: allSuccess
          ? '全部数据$typeName成功'
          : '$typeName完成，部分失败 (失败: $totalFailed)',
      successCount: totalSuccess,
      failedCount: totalFailed,
      failedItems: allFailedItems,
      elapsed: DateTime.now().difference(startTime),
    );
  }
}

/// 下载结果（内部使用）
class _DownloadResult {
  final String url;
  final bool success;
  final FailedItem? failedItem;

  _DownloadResult({required this.url, required this.success, this.failedItem});
}

/// TransferResult 扩展
extension _TransferResultExtension on TransferResult {
  TransferResult _withElapsed(DateTime startTime) {
    return TransferResult(
      success: success,
      message: message,
      successCount: successCount,
      failedCount: failedCount,
      failedItems: failedItems,
      elapsed: DateTime.now().difference(startTime),
    );
  }
}
