import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:torrid/core/services/network/api_client.dart';
import 'package:torrid/core/services/storage/user_data_sync.dart';
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
      final client = ref.read(apiClientManagerProvider);
      final results = <TransferResult>[];
      for (final item in targets) {
        results.add(
          await (type == TransferType.sync || item != TransferTarget.preferences
              ? _sync(item, client)
              : _backup(item, client)),
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

  Future<TransferResult> _sync(TransferTarget target, ApiClient client) async {
    if (target != TransferTarget.preferences) {
      final result = await _backup(target, client);
      if (!result.success) return result;
    }
    return _pull(target, client);
  }

  Future<TransferResult> _pull(TransferTarget target, ApiClient client) async {
    final started = DateTime.now();
    _updateState(
      type: TransferType.sync,
      target: target,
      status: TransferStatus.preparing,
      message: '正在获取${target.displayName}数据...',
    );
    TransferFiles? files;
    try {
      final address = Uri.parse(client.baseUrl).authority;
      final cursorKey = 'cursor|$address|${target.name}';
      final cursor = target == TransferTarget.preferences
          ? 0
          : int.tryParse(userDataSyncBox.get(cursorKey) ?? '') ?? 0;
      Future<Response<dynamic>> fetch(int after) => client.get(
        '/API/user-data/sync/${target.name}',
        queryParams: {
          if (target != TransferTarget.preferences) 'sync_version': 2,
          if (after > 0) 'after': after,
        },
      );

      Response<dynamic> response;
      try {
        response = await fetch(cursor);
      } on DioException catch (error) {
        if (cursor == 0 ||
            error.response?.statusCode != 409 ||
            error.response?.data is! Map ||
            error.response?.data['code'] != 'invalid_sync_cursor') {
          rethrow;
        }
        response = await fetch(0);
      }
      if (response.statusCode != 200 || response.data is! Map) {
        throw const FormatException('服务端返回了无效的数据对象');
      }
      final data = Map<String, dynamic>.from(response.data as Map);
      if (target != TransferTarget.preferences &&
          (data['cursor'] is! int || (data['cursor'] as int) < 0)) {
        throw const FormatException('服务端返回了无效的同步游标');
      }
      if (target == TransferTarget.essay) requireEssaySchema(data);
      final relativeDir = target == TransferTarget.preferences
          ? 'preferences'
          : 'img_storage/${target.name}';
      final local = switch (target) {
        TransferTarget.booklet =>
          ref.read(routineServiceProvider.notifier).snapshot(),
        TransferTarget.essay =>
          ref.read(essayServiceProvider.notifier).snapshot(),
        _ => null,
      };
      final images = _imagePaths(
        target,
        local == null ? data : mergeUserData(target.name, local, data).data,
        relativeDir,
      );
      final directory = await IoService.userDirectory(relativeDir);
      if (target != TransferTarget.preferences) {
        for (final key in images.keys.toList()) {
          final file = File(IoService.safePath(directory, key));
          if (await file.exists() && await file.length() > 0) {
            images.remove(key);
          }
        }
      }
      files = await TransferFiles.create(directory);
      final result = await _downloadImages(client, images, files.staged);
      if (!result.success) {
        _completeTransfer(false, result.message, result.failedItems);
        return result._withElapsed(started);
      }
      await files.apply(() async {
        switch (target) {
          case TransferTarget.booklet:
            await ref
                .read(routineServiceProvider.notifier)
                .syncData(data, cursorKey: cursorKey);
          case TransferTarget.essay:
            await ref
                .read(essayServiceProvider.notifier)
                .syncData(data, cursorKey: cursorKey);
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
      final message = ApiClient.mapError(e).message;
      AppLogger().error('${target.displayName}同步失败: $message');
      _completeTransfer(false, '${target.displayName}同步失败', null, message);
      return TransferResult.failed(
        message: '${target.displayName}同步失败: $message',
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
      final local = path.replaceFirst(RegExp(r'^/'), '');
      final parts = p.posix.split(local);
      if (path.contains('\\') ||
          parts.any((part) => part == '.' || part == '..') ||
          !p.posix.isWithin(root, local) ||
          (target != TransferTarget.preferences && parts.length != 3) ||
          (target == TransferTarget.preferences &&
              (parts.length != 3 ||
                  !['background', 'sidebar', 'avatar'].contains(parts[1])))) {
        throw FormatException('图片路径不在模块目录内: $path');
      }
      final relative = p.posix.relative(local, from: root);
      final remote = target == TransferTarget.preferences
          ? 'img_storage/preferences/${p.basename(local)}'
          : local;
      if (images.entries.any(
        (entry) => entry.key != relative && entry.value == remote,
      )) {
        throw FormatException('图片文件名重复: $path');
      }
      images[relative] = remote;
    }
    return images;
  }

  Future<TransferResult> _backup(
    TransferTarget target,
    ApiClient client,
  ) async {
    final started = DateTime.now();
    _updateState(
      type: TransferType.backup,
      target: target,
      status: TransferStatus.preparing,
      message: '正在准备${target.displayName}备份...',
    );
    try {
      late Map<String, dynamic> data;
      switch (target) {
        case TransferTarget.booklet:
          final service = ref.read(routineServiceProvider.notifier);
          data = await service.packUp();
        case TransferTarget.essay:
          final service = ref.read(essayServiceProvider.notifier);
          data = await service.packUp();
        case TransferTarget.preferences:
          final preferences = packPreferences(
            ref.read(networkConfigManagerProvider),
          );
          data = {
            'jsonData': jsonEncode({'preferences': preferences}),
          };
        case TransferTarget.all:
          throw StateError('请指定数据模块');
      }
      final root = target == TransferTarget.preferences
          ? 'preferences'
          : 'img_storage/${target.name}';
      final images = _imagePaths(
        target,
        Map<String, dynamic>.from(
          jsonDecode(data['jsonData'] as String) as Map,
        ),
        root,
      );
      final directory = await IoService.userDirectory(root);
      final allFiles = <File>[];
      for (final key in images.keys) {
        final file = File(IoService.safePath(directory, key));
        if (await file.exists() && await file.length() > 0) allFiles.add(file);
      }
      final files = await _filterMissingFiles(client, allFiles, target.name);
      _updateProgress(total: files.length + 1, message: '正在备份数据...');
      final result = await _uploadData(
        client: client,
        path:
            '/API/user-data/${target == TransferTarget.preferences ? 'backup' : 'sync'}/${target.name}',
        jsonData: data,
        files: files,
      );
      _completeTransfer(
        result.success,
        '${target.displayName}: ${result.message}',
        null,
        result.success ? null : result.message,
      );
      return result._withElapsed(
        started,
        message: '${target.displayName}: ${result.message}',
      );
    } catch (e) {
      final message = ApiClient.mapError(e).message;
      AppLogger().error('${target.displayName}备份失败: $message');
      _completeTransfer(false, '${target.displayName}备份失败', null, message);
      return TransferResult.failed(
        message: '${target.displayName}备份失败: $message',
        elapsed: DateTime.now().difference(started),
      );
    }
  }

  /// 向服务端查询哪些图片文件已存在，返回仅需上传的缺失文件列表
  /// 若查询失败则回退为全量上传（返回原列表）
  Future<List<File>> _filterMissingFiles(
    ApiClient client,
    List<File> allFiles,
    String module,
  ) async {
    if (allFiles.isEmpty && module != 'essay') return allFiles;

    try {
      final filenames = allFiles.map((f) => p.basename(f.path)).toList();
      final resp = await client.postJson(
        "/API/user-data/check-images/$module",
        data: {"filenames": filenames},
      );

      if (module == 'essay') requireEssaySchema(resp.data);
      if (resp.statusCode != 200) return allFiles;

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
    ApiClient client,
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
        batch.map((image) => _downloadImage(client, image, directory)),
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
    ApiClient client,
    MapEntry<String, String> image,
    Directory directory,
  ) async {
    for (var attempt = 0; ; attempt++) {
      try {
        final response = await client.getBinary(
          Uri(path: '/static/${image.value}').toString(),
        );
        if (response.statusCode != 200 || response.data?.isEmpty != false) {
          throw StateError('图片响应无效: ${response.statusCode}');
        }
        final file = File(IoService.safePath(directory, image.key));
        await file.parent.create(recursive: true);
        await file.writeAsBytes(response.data!, flush: true);
        return null;
      } catch (e) {
        if (attempt >= _maxRetries) {
          return FailedItem(
            name: image.key,
            path: image.value,
            error: ApiClient.mapError(e).message,
            retryCount: attempt,
          );
        }
        await Future<void>.delayed(_retryDelay);
      }
    }
  }

  Future<TransferResult> _uploadData({
    required ApiClient client,
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
      final resp = await client.post(
        path,
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
      );

      if (resp.statusCode == 200 &&
          resp.data is Map &&
          resp.data['status'] == 'success') {
        return TransferResult.success(
          message: '上传成功',
          successCount: files.length + 1,
        );
      }
      return TransferResult.failed(
        message: '服务端未确认写入成功 (HTTP ${resp.statusCode})',
      );
    } catch (e) {
      return TransferResult.failed(
        message: '上传出错: ${ApiClient.mapError(e).message}',
      );
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
      allSuccess
          ? null
          : results.where((r) => !r.success).map((r) => r.message).join('\n'),
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
  TransferResult _withElapsed(DateTime startTime, {String? message}) {
    return TransferResult(
      success: success,
      message: message ?? this.message,
      successCount: successCount,
      failedCount: failedCount,
      failedItems: failedItems,
      elapsed: DateTime.now().difference(startTime),
    );
  }
}
