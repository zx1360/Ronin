/// 数据传输服务
/// 
/// 提供并发传输、进度跟踪、重试机制等功能。
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/booklet/providers/providers.dart';
import 'package:torrid/features/essay/providers/essay_notifier_provider.dart';
import 'package:torrid/features/profile/second_page/data/models/transfer_progress.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';
import 'package:torrid/core/services/debug/logging_service.dart';
import 'package:torrid/core/services/io/io_service.dart';

part 'transfer_service.g.dart';

/// 配置常量
const int _maxConcurrent = 5;         // 最大并发数
const int _maxRetries = 3;            // 最大重试次数
const Duration _retryDelay = Duration(milliseconds: 300); // 重试间隔
const Duration _batchDelay = Duration(milliseconds: 50);  // 批次间隔

// ============================================================================
// 传输进度状态管理
// ============================================================================

/// 传输进度状态提供者
@riverpod
class TransferState extends _$TransferState {
  @override
  TransferProgress build() => TransferProgress.empty();

  /// 开始新的传输任务
  void startTransfer({
    required TransferType type,
    required TransferTarget target,
    required int total,
    String message = '',
  }) {
    state = TransferProgress(
      type: type,
      target: target,
      status: TransferStatus.preparing,
      total: total,
      current: 0,
      message: message.isEmpty ? '正在准备${type == TransferType.sync ? "同步" : "备份"}...' : message,
      startTime: DateTime.now(),
    );
  }

  /// 更新进度
  void updateProgress({
    int? total,
    int? current,
    String? currentMessage,
    String? message,
    TransferStatus? status,
  }) {
    state = state.copyWith(
      total: total ?? state.total,
      current: current ?? state.current,
      currentMessage: currentMessage ?? state.currentMessage,
      message: message ?? state.message,
      status: status ?? (state.status == TransferStatus.preparing ? TransferStatus.inProgress : state.status),
    );
  }

  /// 增加进度
  void incrementProgress({String? currentMessage}) {
    state = state.copyWith(
      current: state.current + 1,
      currentMessage: currentMessage ?? state.currentMessage,
      status: state.status == TransferStatus.preparing ? TransferStatus.inProgress : state.status,
    );
  }

  /// 开始重试
  void startRetrying(List<FailedItem> failedItems) {
    state = state.copyWith(
      status: TransferStatus.retrying,
      failedItems: failedItems,
      message: '正在重试失败项...',
    );
  }

  /// 完成传输
  void completeTransfer({
    required bool success,
    String? message,
    List<FailedItem>? failedItems,
    String? errorMessage,
  }) {
    state = state.copyWith(
      status: success ? TransferStatus.success : TransferStatus.failed,
      message: message ?? (success ? '传输完成' : '传输失败'),
      failedItems: failedItems ?? state.failedItems,
      errorMessage: errorMessage,
      endTime: DateTime.now(),
    );
  }

  /// 重置状态
  void reset() {
    state = TransferProgress.empty();
  }
}

// ============================================================================
// 同步服务（从PC到本地）
// ============================================================================

/// 同步打卡数据（支持进度跟踪和并发下载）
@riverpod
Future<TransferResult> syncBookletWithProgress(SyncBookletWithProgressRef ref) async {
  final transferState = ref.read(transferStateProvider.notifier);
  final startTime = DateTime.now();
  
  try {
    transferState.startTransfer(
      type: TransferType.sync,
      target: TransferTarget.booklet,
      total: 0,
      message: '正在获取打卡数据...',
    );

    // 1. 获取打卡数据
    final resp = await ref.read(fetcherProvider(path: "/api/user-data/sync/booklet").future);
    if (resp == null || resp.statusCode != 200) {
      throw Exception("获取打卡数据失败");
    }

    // 2. 解析数据并同步
    final data = resp.data;
    await ref.read(routineServiceProvider.notifier).syncData(data);

    // 3. 收集需要下载的图片URL
    final List<String> imageUrls = [];
    final styles = data['styles'] as List? ?? [];
    for (final style in styles) {
      final tasks = style['tasks'] as List? ?? [];
      for (final task in tasks) {
        final image = task['image'] as String?;
        if (image != null && image.isNotEmpty) {
          imageUrls.add(image);
        }
      }
    }

    // 4. 并发下载图片
    if (imageUrls.isNotEmpty) {
      final result = await _downloadImagesWithProgress(
        ref: ref,
        urls: imageUrls,
        relativeDir: "img_storage/booklet",
        transferState: transferState,
      );
      
      if (!result.success && result.failedItems.isNotEmpty) {
        return TransferResult.failed(
          message: '打卡同步完成，但有${result.failedCount}张图片下载失败',
          successCount: result.successCount,
          failedCount: result.failedCount,
          failedItems: result.failedItems,
          elapsed: DateTime.now().difference(startTime),
        );
      }
    }

    transferState.completeTransfer(success: true, message: '打卡数据同步完成');
    return TransferResult.success(
      message: '打卡数据同步成功',
      successCount: imageUrls.length,
      elapsed: DateTime.now().difference(startTime),
    );
  } catch (e) {
    AppLogger().error("syncBookletWithProgress出错: $e");
    transferState.completeTransfer(
      success: false,
      message: '打卡同步失败',
      errorMessage: e.toString(),
    );
    return TransferResult.failed(
      message: '打卡同步失败: $e',
      elapsed: DateTime.now().difference(startTime),
    );
  }
}

/// 同步随笔数据（支持进度跟踪和并发下载）
@riverpod
Future<TransferResult> syncEssayWithProgress(SyncEssayWithProgressRef ref) async {
  final transferState = ref.read(transferStateProvider.notifier);
  final startTime = DateTime.now();
  
  try {
    transferState.startTransfer(
      type: TransferType.sync,
      target: TransferTarget.essay,
      total: 0,
      message: '正在获取随笔数据...',
    );

    // 1. 获取随笔数据
    final resp = await ref.read(fetcherProvider(path: "/api/user-data/sync/essay").future);
    if (resp == null || resp.statusCode != 200) {
      throw Exception("获取随笔数据失败");
    }

    // 2. 解析数据并同步
    final data = resp.data;
    await ref.read(essayServiceProvider.notifier).syncData(data);

    // 3. 收集需要下载的图片URL
    final List<String> imageUrls = [];
    final essays = data['essays'] as List? ?? [];
    for (final essay in essays) {
      final imgs = essay['imgs'] as List? ?? [];
      for (final img in imgs) {
        if (img != null && img.toString().isNotEmpty) {
          imageUrls.add(img.toString());
        }
      }
    }

    // 4. 并发下载图片
    if (imageUrls.isNotEmpty) {
      final result = await _downloadImagesWithProgress(
        ref: ref,
        urls: imageUrls,
        relativeDir: "img_storage/essay",
        transferState: transferState,
      );
      
      if (!result.success && result.failedItems.isNotEmpty) {
        return TransferResult.failed(
          message: '随笔同步完成，但有${result.failedCount}张图片下载失败',
          successCount: result.successCount,
          failedCount: result.failedCount,
          failedItems: result.failedItems,
          elapsed: DateTime.now().difference(startTime),
        );
      }
    }

    transferState.completeTransfer(success: true, message: '随笔数据同步完成');
    return TransferResult.success(
      message: '随笔数据同步成功',
      successCount: imageUrls.length,
      elapsed: DateTime.now().difference(startTime),
    );
  } catch (e) {
    AppLogger().error("syncEssayWithProgress出错: $e");
    transferState.completeTransfer(
      success: false,
      message: '随笔同步失败',
      errorMessage: e.toString(),
    );
    return TransferResult.failed(
      message: '随笔同步失败: $e',
      elapsed: DateTime.now().difference(startTime),
    );
  }
}

/// 同步所有数据
@riverpod
Future<TransferResult> syncAllWithProgress(SyncAllWithProgressRef ref) async {
  final startTime = DateTime.now();
  final results = <TransferResult>[];
  
  // 同步打卡数据
  final bookletResult = await ref.read(syncBookletWithProgressProvider.future);
  results.add(bookletResult);
  
  // 同步随笔数据
  final essayResult = await ref.read(syncEssayWithProgressProvider.future);
  results.add(essayResult);
  
  final totalSuccess = results.fold(0, (sum, r) => sum + r.successCount);
  final totalFailed = results.fold(0, (sum, r) => sum + r.failedCount);
  final allFailedItems = results.expand((r) => r.failedItems).toList();
  final allSuccess = results.every((r) => r.success);
  
  return TransferResult(
    success: allSuccess,
    message: allSuccess 
        ? '全部数据同步成功' 
        : '同步完成，部分失败 (失败: $totalFailed)',
    successCount: totalSuccess,
    failedCount: totalFailed,
    failedItems: allFailedItems,
    elapsed: DateTime.now().difference(startTime),
  );
}

// ============================================================================
// 备份服务（从本地到PC）
// ============================================================================

/// 备份打卡数据（支持进度跟踪和并发上传）
@riverpod
Future<TransferResult> backupBookletWithProgress(BackupBookletWithProgressRef ref) async {
  final transferState = ref.read(transferStateProvider.notifier);
  final startTime = DateTime.now();
  
  try {
    final notifier = ref.read(routineServiceProvider.notifier);
    final data = notifier.packUp();
    
    // 获取需要上传的图片文件
    final externalDir = await IoService.externalStorageDir;
    final imgPaths = notifier.getImgsPath();
    final files = imgPaths
        .map((p) => File("${externalDir.path}/$p"))
        .where((f) => f.existsSync())
        .toList();

    transferState.startTransfer(
      type: TransferType.backup,
      target: TransferTarget.booklet,
      total: files.length + 1, // +1 表示JSON数据
      message: '正在备份打卡数据...',
    );

    // 上传数据和文件
    final result = await _uploadWithProgress(
      ref: ref,
      path: "/api/user-data/backup/booklet",
      jsonData: data,
      files: files,
      transferState: transferState,
    );

    if (result.success) {
      transferState.completeTransfer(success: true, message: '打卡数据备份完成');
    } else {
      transferState.completeTransfer(
        success: false,
        message: '打卡备份失败',
        errorMessage: result.message,
      );
    }

    return result.copyWith(
      elapsed: DateTime.now().difference(startTime),
    );
  } catch (e) {
    AppLogger().error("backupBookletWithProgress出错: $e");
    transferState.completeTransfer(
      success: false,
      message: '打卡备份失败',
      errorMessage: e.toString(),
    );
    return TransferResult.failed(
      message: '打卡备份失败: $e',
      elapsed: DateTime.now().difference(startTime),
    );
  }
}

/// 备份随笔数据（支持进度跟踪和并发上传）
@riverpod
Future<TransferResult> backupEssayWithProgress(BackupEssayWithProgressRef ref) async {
  final transferState = ref.read(transferStateProvider.notifier);
  final startTime = DateTime.now();
  
  try {
    final notifier = ref.read(essayServiceProvider.notifier);
    final data = notifier.packUp();
    
    // 获取需要上传的图片文件
    final externalDir = await IoService.externalStorageDir;
    final imgPaths = notifier.getImgsPath();
    final files = imgPaths
        .map((p) => File("${externalDir.path}/$p"))
        .where((f) => f.existsSync())
        .toList();

    transferState.startTransfer(
      type: TransferType.backup,
      target: TransferTarget.essay,
      total: files.length + 1, // +1 表示JSON数据
      message: '正在备份随笔数据...',
    );

    // 上传数据和文件
    final result = await _uploadWithProgress(
      ref: ref,
      path: "/api/user-data/backup/essay",
      jsonData: data,
      files: files,
      transferState: transferState,
    );

    if (result.success) {
      transferState.completeTransfer(success: true, message: '随笔数据备份完成');
    } else {
      transferState.completeTransfer(
        success: false,
        message: '随笔备份失败',
        errorMessage: result.message,
      );
    }

    return result.copyWith(
      elapsed: DateTime.now().difference(startTime),
    );
  } catch (e) {
    AppLogger().error("backupEssayWithProgress出错: $e");
    transferState.completeTransfer(
      success: false,
      message: '随笔备份失败',
      errorMessage: e.toString(),
    );
    return TransferResult.failed(
      message: '随笔备份失败: $e',
      elapsed: DateTime.now().difference(startTime),
    );
  }
}

/// 备份所有数据
@riverpod
Future<TransferResult> backupAllWithProgress(BackupAllWithProgressRef ref) async {
  final startTime = DateTime.now();
  final results = <TransferResult>[];
  
  // 备份打卡数据
  final bookletResult = await ref.read(backupBookletWithProgressProvider.future);
  results.add(bookletResult);
  
  // 备份随笔数据
  final essayResult = await ref.read(backupEssayWithProgressProvider.future);
  results.add(essayResult);
  
  final totalSuccess = results.fold(0, (sum, r) => sum + r.successCount);
  final totalFailed = results.fold(0, (sum, r) => sum + r.failedCount);
  final allFailedItems = results.expand((r) => r.failedItems).toList();
  final allSuccess = results.every((r) => r.success);
  
  return TransferResult(
    success: allSuccess,
    message: allSuccess 
        ? '全部数据备份成功' 
        : '备份完成，部分失败 (失败: $totalFailed)',
    successCount: totalSuccess,
    failedCount: totalFailed,
    failedItems: allFailedItems,
    elapsed: DateTime.now().difference(startTime),
  );
}

// ============================================================================
// 内部辅助函数
// ============================================================================

/// 并发下载图片（带进度跟踪和重试）
Future<TransferResult> _downloadImagesWithProgress({
  required dynamic ref,
  required List<String> urls,
  required String relativeDir,
  required TransferState transferState,
}) async {
  if (urls.isEmpty) {
    return TransferResult.success(message: '无图片需要下载');
  }

  // 更新总数
  transferState.updateProgress(
    total: urls.length,
    message: '正在下载图片...',
    status: TransferStatus.inProgress,
  );

  // 清理并创建目录
  await IoService.clearSpecificDirectory(relativeDir);
  final externalDir = await IoService.externalStorageDir;
  final targetDir = path.join(externalDir.path, relativeDir);
  final directory = Directory(targetDir);
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }

  // 准备下载任务
  final failedItems = <FailedItem>[];
  int successCount = 0;

  // 分批执行下载
  final batches = <List<String>>[];
  for (int i = 0; i < urls.length; i += _maxConcurrent) {
    final end = (i + _maxConcurrent > urls.length) ? urls.length : i + _maxConcurrent;
    batches.add(urls.sublist(i, end));
  }

  for (final batch in batches) {
    final futures = batch.map((url) async {
      try {
        final response = await ref.read(
          bytesFetcherProvider(path: "/static/$url").future,
        );
        if (response == null || response.statusCode != 200) {
          throw Exception('图片请求失败: 状态码 ${response?.statusCode}');
        }

        final Uint8List imageData = response.data!;
        final String fileName = path.basename(url);
        final String savePath = path.join(targetDir, fileName);
        final File imageFile = File(savePath);
        await imageFile.writeAsBytes(imageData);
        
        return (success: true, url: url, error: '');
      } catch (e) {
        return (success: false, url: url, error: e.toString());
      }
    }).toList();

    final results = await Future.wait(futures);
    
    for (final result in results) {
      if (result.success) {
        successCount++;
      } else {
        failedItems.add(FailedItem(
          name: path.basename(result.url),
          path: result.url,
          error: result.error,
        ));
      }
      transferState.incrementProgress(
        currentMessage: path.basename(result.url),
      );
    }

    // 批次间延迟
    await Future.delayed(_batchDelay);
  }

  // 重试失败的项目
  if (failedItems.isNotEmpty) {
    transferState.startRetrying(failedItems);
    final retriedItems = await _retryDownloads(
      ref: ref,
      failedItems: failedItems,
      targetDir: targetDir,
      transferState: transferState,
    );
    
    // 更新成功和失败数量
    final stillFailed = retriedItems.where((item) => item.retryCount >= _maxRetries).toList();
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

/// 重试下载失败的项目
Future<List<FailedItem>> _retryDownloads({
  required dynamic ref,
  required List<FailedItem> failedItems,
  required String targetDir,
  required TransferState transferState,
}) async {
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
          final Uint8List imageData = response.data!;
          final String savePath = path.join(targetDir, item.name);
          final File imageFile = File(savePath);
          await imageFile.writeAsBytes(imageData);
          success = true;
          AppLogger().info("重试成功: ${item.name}");
        }
      } catch (e) {
        lastError = e.toString();
        AppLogger().warning("重试失败 ($retryCount/$_maxRetries): ${item.name}");
      }
    }

    if (!success) {
      stillFailed.add(item.copyWith(
        retryCount: retryCount,
        error: lastError,
      ));
    }
  }

  return stillFailed;
}

/// 上传数据和文件（带进度跟踪）
Future<TransferResult> _uploadWithProgress({
  required dynamic ref,
  required String path,
  required Map<String, dynamic> jsonData,
  required List<File> files,
  required TransferState transferState,
}) async {
  try {
    transferState.updateProgress(
      current: 0,
      message: '正在上传数据...',
      status: TransferStatus.inProgress,
    );

    // 使用带进度回调的上传
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
              transferState.updateProgress(
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
    } else {
      return TransferResult.failed(
        message: '上传失败: 状态码 ${resp?.statusCode}',
      );
    }
  } catch (e) {
    return TransferResult.failed(
      message: '上传出错: $e',
    );
  }
}

// ============================================================================
// TransferResult 扩展
// ============================================================================

extension TransferResultExtension on TransferResult {
  TransferResult copyWith({
    bool? success,
    String? message,
    int? successCount,
    int? failedCount,
    List<FailedItem>? failedItems,
    Duration? elapsed,
  }) {
    return TransferResult(
      success: success ?? this.success,
      message: message ?? this.message,
      successCount: successCount ?? this.successCount,
      failedCount: failedCount ?? this.failedCount,
      failedItems: failedItems ?? this.failedItems,
      elapsed: elapsed ?? this.elapsed,
    );
  }
}
