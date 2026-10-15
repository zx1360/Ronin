import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/core/services/debug/logging_service.dart';
import 'package:torrid/core/services/io/io_service.dart';
import 'package:torrid/features/booklet/providers/providers.dart';
import 'package:torrid/features/essay/providers/essay_notifier_provider.dart';
import 'package:torrid/features/essay/services/essay_contract.dart';
import 'package:torrid/features/profile/second_page/data/models/transfer_progress.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';
import 'package:torrid/providers/network_config/network_config_provider.dart';
import 'package:torrid/providers/personalization/personalization_providers.dart';

import 'preferences_transfer.dart';
import 'transfer_files.dart';

part 'transfer_controller.g.dart';

const int _maxConcurrent = 5;
const int _maxRetries = 3;
const Duration _retryDelay = Duration(milliseconds: 300);

@riverpod
class TransferController extends _$TransferController {
  bool _running = false;

  @override
  TransferProgress build() => TransferProgress.idle();

  Future<TransferResult> execute({
    required TransferType type,
    required TransferTarget target,
  }) async {
    if (_running) {
      return TransferResult.failed(message: '有传输任务正在进行中');
    }
    _running = true;
    final keepAlive = ref.keepAlive();
    final started = DateTime.now();
    final targets = target == TransferTarget.all
        ? [
            TransferTarget.booklet,
            TransferTarget.essay,
            TransferTarget.preferences,
          ]
        : [target];
    try {
      final results = <TransferResult>[];
      for (final item in targets) {
        results.add(
          await (type == TransferType.sync ? _sync(item) : _backup(item)),
        );
      }
      return results.length == 1
          ? results.single
          : _combineResults(results, type, started);
    } finally {
      _running = false;
      keepAlive.close();
    }
  }

  Future<TransferResult> syncAll() =>
      execute(type: TransferType.sync, target: TransferTarget.all);

  Future<TransferResult> backupAll() =>
      execute(type: TransferType.backup, target: TransferTarget.all);

  void reset() {
    if (!_running) state = TransferProgress.idle();
  }

  Future<TransferResult> _sync(TransferTarget target) async {
    final started = DateTime.now();
    _updateState(
      type: TransferType.sync,
      target: target,
      status: TransferStatus.preparing,
      message: '正在获取${target.displayName}数据...',
    );
    TransferFiles? files;
    try {
      final response = await ref.read(
        fetcherProvider(path: '/API/user-data/sync/${target.name}').future,
      );
      if (response == null || response.statusCode != 200) {
        throw StateError('获取数据失败');
      }
      final data = Map<String, dynamic>.from(response.data as Map);
      if (target == TransferTarget.essay) requireEssaySchema(data);
      final relativeDir = target == TransferTarget.preferences
          ? 'preferences'
          : 'img_storage/${target.name}';
      final images = _imagePaths(target, data, relativeDir);
      final externalDir = await IoService.externalStorageDir;
      files = await TransferFiles.create(
        Directory(p.join(externalDir.path, relativeDir)),
      );
      final result = await _downloadImages(images, files.staged);
      if (!result.success) {
        _completeTransfer(false, result.message, result.failedItems);
        return result._withElapsed(started);
      }
      await files.apply(() async {
        switch (target) {
          case TransferTarget.booklet:
            await ref.read(routineServiceProvider.notifier).syncData(data);
          case TransferTarget.essay:
            await ref.read(essayServiceProvider.notifier).syncData(data);
          case TransferTarget.preferences:
            await restorePreferences(
              Map<String, dynamic>.from(data['preferences'] as Map),
            );
          case TransferTarget.all:
            throw StateError('请指定数据模块');
        }
      });
      if (target == TransferTarget.preferences) {
        await ref.read(networkConfigManagerProvider.notifier).refresh();
        ref.read(appSettingsProvider.notifier).refresh();
      }
      _completeTransfer(true, '${target.displayName}同步完成');
      return TransferResult.success(
        message: '${target.displayName}同步成功',
        successCount: images.length,
        elapsed: DateTime.now().difference(started),
      );
    } catch (e) {
      AppLogger().error('${target.displayName}同步失败: $e');
      _completeTransfer(false, '同步失败', null, e.toString());
      return TransferResult.failed(
        message: '同步失败: $e',
        elapsed: DateTime.now().difference(started),
      );
    } finally {
      await files?.dispose();
    }
  }

  Map<String, String> _imagePaths(
    TransferTarget target,
    Map<String, dynamic> data,
    String root,
  ) {
    final paths = switch (target) {
      TransferTarget.booklet => _extractBookletImageUrls(data),
      TransferTarget.essay => _extractEssayImageUrls(data),
      TransferTarget.preferences => preferenceImagePaths(
        Map<String, dynamic>.from(data['preferences'] as Map),
      ),
      TransferTarget.all => throw StateError('请指定数据模块'),
    };
    final images = <String, String>{};
    for (final path in paths.where((path) => path.isNotEmpty)) {
      final local = p.normalize(path.replaceFirst(RegExp(r'^/'), ''));
      if (!p.isWithin(root, local)) throw FormatException('图片路径不在模块目录内: $path');
      images[p.relative(
        local,
        from: root,
      )] = target == TransferTarget.preferences
          ? 'img_storage/preferences/${p.basename(local)}'
          : local.replaceAll('\\', '/');
    }
    return images;
  }

  Future<TransferResult> _backup(TransferTarget target) async {
    final started = DateTime.now();
    _updateState(
      type: TransferType.backup,
      target: target,
      status: TransferStatus.preparing,
      message: '正在准备${target.displayName}备份...',
    );
    try {
      late Map<String, dynamic> data;
      late List<String> images;
      switch (target) {
        case TransferTarget.booklet:
          final service = ref.read(routineServiceProvider.notifier);
          data = service.packUp();
          images = service.getImgsPath();
        case TransferTarget.essay:
          final service = ref.read(essayServiceProvider.notifier);
          data = service.packUp();
          images = service.getImgsPath();
        case TransferTarget.preferences:
          final preferences = packPreferences();
          data = {
            'jsonData': jsonEncode({'preferences': preferences}),
          };
          images = preferenceImagePaths(preferences);
        case TransferTarget.all:
          throw StateError('请指定数据模块');
      }
      final externalDir = await IoService.externalStorageDir;
      final allFiles = images
          .toSet()
          .map((path) => File(p.join(externalDir.path, path)))
          .where((file) => file.existsSync())
          .toList();
      final files = await _filterMissingFiles(allFiles, target.name);
      _updateProgress(total: files.length + 1, message: '正在备份数据...');
      final result = await _uploadData(
        path: '/API/user-data/backup/${target.name}',
        jsonData: data,
        files: files,
      );
      _completeTransfer(result.success, result.message);
      return result._withElapsed(started);
    } catch (e) {
      AppLogger().error('${target.displayName}备份失败: $e');
      _completeTransfer(false, '备份失败', null, e.toString());
      return TransferResult.failed(
        message: '备份失败: $e',
        elapsed: DateTime.now().difference(started),
      );
    }
  }

  /// 向服务端查询哪些图片文件已存在，返回仅需上传的缺失文件列表
  /// 若查询失败则回退为全量上传（返回原列表）
  Future<List<File>> _filterMissingFiles(
    List<File> allFiles,
    String module,
  ) async {
    if (allFiles.isEmpty && module != 'essay') return allFiles;

    try {
      final filenames = allFiles.map((f) => p.basename(f.path)).toList();
      final resp = await ref.read(
        jsonSenderProvider(
          path: "/API/user-data/check-images/$module",
          data: {"filenames": filenames},
        ).future,
      );

      if (module == 'essay') requireEssaySchema(resp?.data);
      if (resp == null || resp.statusCode != 200) return allFiles;

      final missing = (resp.data['missing'] as List?)
          ?.map((e) => e.toString())
          .toSet();
      if (missing == null) return allFiles;
      if (missing.isEmpty) return [];

      return allFiles
          .where((f) => missing.contains(p.basename(f.path)))
          .toList();
    } catch (e) {
      if (module == 'essay') rethrow;
      AppLogger().warning("检查服务端已有图片失败，回退全量上传: $e");
      return allFiles; // 查询失败时回退为全量上传
    }
  }

  Future<TransferResult> _downloadImages(
    Map<String, String> images,
    Directory directory,
  ) async {
    _updateProgress(
      total: images.length,
      message: '正在下载图片...',
      status: TransferStatus.inProgress,
    );
    final failed = <FailedItem>[];
    for (final batch in _createBatches(
      images.entries.toList(),
      _maxConcurrent,
    )) {
      final results = await Future.wait(
        batch.map((image) => _downloadImage(image, directory)),
      );
      for (var i = 0; i < results.length; i++) {
        if (results[i] != null) failed.add(results[i]!);
        _incrementProgress(p.basename(batch[i].key));
      }
    }
    return failed.isEmpty
        ? TransferResult.success(message: '图片下载完成', successCount: images.length)
        : TransferResult.failed(
            message: '${failed.length} 个文件下载失败，原数据已保留',
            successCount: images.length - failed.length,
            failedCount: failed.length,
            failedItems: failed,
          );
  }

  Future<FailedItem?> _downloadImage(
    MapEntry<String, String> image,
    Directory directory,
  ) async {
    for (var attempt = 0; ; attempt++) {
      try {
        final response = await ref.read(
          bytesFetcherProvider(path: '/static/${image.value}').future,
        );
        if (response?.statusCode != 200 || response?.data?.isEmpty != false) {
          throw StateError('图片响应无效: ${response?.statusCode}');
        }
        final file = File(p.join(directory.path, image.key));
        await file.parent.create(recursive: true);
        await file.writeAsBytes(response!.data!, flush: true);
        return null;
      } catch (e) {
        if (attempt >= _maxRetries) {
          return FailedItem(
            name: image.key,
            path: image.value,
            error: e.toString(),
            retryCount: attempt,
          );
        }
        await Future<void>.delayed(_retryDelay);
      }
    }
  }

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
