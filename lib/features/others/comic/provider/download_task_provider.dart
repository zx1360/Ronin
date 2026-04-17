library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import 'package:torrid/core/services/debug/logging_service.dart';
import 'package:torrid/core/services/io/io_service.dart';
import 'package:torrid/core/services/network/api_client.dart';
import 'package:torrid/core/services/storage/prefs_service.dart';
import 'package:torrid/features/others/comic/models/chapter_info.dart';
import 'package:torrid/features/others/comic/models/comic_download_task.dart';
import 'package:torrid/features/others/comic/models/comic_info.dart';
import 'package:torrid/features/others/comic/provider/box_provider.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

final comicDownloadTasksProvider =
    StateNotifierProvider<ComicDownloadTaskNotifier, List<ComicDownloadTask>>(
      (ref) => ComicDownloadTaskNotifier(ref),
    );

class ComicDownloadTaskNotifier extends StateNotifier<List<ComicDownloadTask>> {
  ComicDownloadTaskNotifier(this._ref) : super(const []) {
    unawaited(initialize());
  }

  static const String _prefsKey = 'comic_download_tasks_v1';
  static const int _maxConcurrentComics = 2;
  static const int _maxConcurrentImagesPerComic = 3;
  static const int _maxTaskRetryCount = 50;
  static const int _maxImageRetryRounds = 2;

  final Ref _ref;

  bool _initialized = false;
  bool _isScheduling = false;

  final Set<String> _runningTaskIds = <String>{};
  final Map<String, List<CancelToken>> _taskCancelTokens = {};

  Timer? _retryTimer;
  Timer? _persistTimer;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final raw = PrefsService().prefs.getString(_prefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = (jsonDecode(raw) as List)
            .map(
              (row) => ComicDownloadTask.fromJson(
                Map<String, dynamic>.from(row as Map),
              ),
            )
            .toList();
        state = list;
      } catch (e) {
        AppLogger().warning('恢复漫画下载任务失败，将清空任务缓存: $e');
        state = const [];
      }
    }

    final now = _nowMs;
    // 应用重启时，运行中的任务恢复为排队中。
    state = state.map((task) {
      if (task.status == ComicDownloadTaskStatus.running) {
        return task.copyWith(
          status: ComicDownloadTaskStatus.queued,
          updatedAtMs: now,
          clearErrorMessage: true,
          clearNextRetryAtMs: true,
        );
      }
      return task;
    }).toList();

    await _persistNow();
    _schedule();
  }

  Future<ComicDownloadTask?> enqueueComic({
    required ComicInfo comicInfo,
  }) async {
    await initialize();

    final running = _firstTaskWhere(
      (task) => task.comicId == comicInfo.id && !task.isTerminal,
    );
    if (running != null) {
      return null;
    }

    // 保留一个同漫画的最新任务，避免任务列表被历史记录占满。
    state = state.where((task) => task.comicId != comicInfo.id).toList();

    final task = ComicDownloadTask.newTask(
      taskId: const Uuid().v4(),
      comicId: comicInfo.id,
      comicName: comicInfo.comicName,
      coverImage: comicInfo.coverImage,
    );
    state = [task, ...state];

    _persistSoon();
    _schedule();
    return task;
  }

  Future<void> pauseTask(String taskId) async {
    await initialize();
    final task = _taskById(taskId);
    if (task == null) return;

    if (task.status == ComicDownloadTaskStatus.running) {
      _cancelTokensForTask(taskId, reason: 'pause');
    }

    _updateTask(
      taskId,
      (old) => old.copyWith(
        status: ComicDownloadTaskStatus.paused,
        updatedAtMs: _nowMs,
      ),
    );
  }

  Future<void> resumeTask(String taskId) async {
    await initialize();
    final task = _taskById(taskId);
    if (task == null || !task.canResume) return;

    _updateTask(
      taskId,
      (old) => old.copyWith(
        status: ComicDownloadTaskStatus.queued,
        retryCount: 0,
        clearErrorMessage: true,
        clearNextRetryAtMs: true,
        updatedAtMs: _nowMs,
      ),
    );
    _schedule();
  }

  Future<void> cancelTask(
    String taskId, {
    bool deleteLocalFiles = false,
  }) async {
    await initialize();
    final task = _taskById(taskId);
    if (task == null) return;

    _cancelTokensForTask(taskId, reason: 'cancel');

    _updateTask(
      taskId,
      (old) => old.copyWith(
        status: ComicDownloadTaskStatus.canceled,
        updatedAtMs: _nowMs,
        clearNextRetryAtMs: true,
      ),
    );

    if (deleteLocalFiles) {
      await IoService.clearSpecificDirectory(
        path.join('comics', task.comicName),
      );
      await _removeComicMeta(task.comicId);
    }
  }

  Future<void> removeTask(String taskId) async {
    await initialize();
    final task = _taskById(taskId);
    if (task == null || !task.isTerminal) return;

    state = state.where((item) => item.taskId != taskId).toList();
    await _persistNow();
    _schedule();
  }

  Future<void> clearFinishedTasks() async {
    await initialize();
    state = state.where((task) => !task.isTerminal).toList();
    await _persistNow();
  }

  void _schedule() {
    if (!_initialized || _isScheduling) return;

    _isScheduling = true;
    Future<void>(() async {
      try {
        while (_runningTaskIds.length < _maxConcurrentComics) {
          final next = _pickNextRunnableTask();
          if (next == null) break;

          _runningTaskIds.add(next.taskId);
          _updateTask(
            next.taskId,
            (old) => old.copyWith(
              status: ComicDownloadTaskStatus.running,
              clearErrorMessage: true,
              clearNextRetryAtMs: true,
              updatedAtMs: _nowMs,
            ),
          );
          unawaited(_runTask(next.taskId));
        }
      } finally {
        _isScheduling = false;
        _setupRetryTimer();
      }
    });
  }

  ComicDownloadTask? _pickNextRunnableTask() {
    final now = _nowMs;
    final candidates = state.where((task) {
      if (_runningTaskIds.contains(task.taskId)) return false;
      if (task.status == ComicDownloadTaskStatus.queued) return true;
      if (task.status == ComicDownloadTaskStatus.retryWaiting) {
        final retryAt = task.nextRetryAtMs ?? 0;
        return retryAt <= now;
      }
      return false;
    }).toList()..sort((a, b) => a.createdAtMs.compareTo(b.createdAtMs));

    return candidates.isEmpty ? null : candidates.first;
  }

  Future<void> _runTask(String taskId) async {
    try {
      await _downloadComic(taskId);
    } on _TaskPausedException {
      // 暂停属于预期控制流，这里不额外处理。
    } on _TaskCanceledException {
      // 取消属于预期控制流，这里不额外处理。
    } catch (e, st) {
      AppLogger().error('漫画下载任务失败: $taskId, error: $e');
      AppLogger().error(st.toString());

      final task = _taskById(taskId);
      if (task == null) return;
      if (task.status == ComicDownloadTaskStatus.paused ||
          task.status == ComicDownloadTaskStatus.canceled) {
        return;
      }

      final nextRetryCount = task.retryCount + 1;
      if (nextRetryCount <= _maxTaskRetryCount) {
        final waitSeconds = min(180, 5 * nextRetryCount);
        final nextRetryAt = DateTime.now()
            .add(Duration(seconds: waitSeconds))
            .millisecondsSinceEpoch;
        _updateTask(
          taskId,
          (old) => old.copyWith(
            status: ComicDownloadTaskStatus.retryWaiting,
            retryCount: nextRetryCount,
            nextRetryAtMs: nextRetryAt,
            errorMessage: e.toString(),
            updatedAtMs: _nowMs,
          ),
        );
      } else {
        _updateTask(
          taskId,
          (old) => old.copyWith(
            status: ComicDownloadTaskStatus.failed,
            retryCount: nextRetryCount,
            errorMessage: e.toString(),
            clearNextRetryAtMs: true,
            updatedAtMs: _nowMs,
          ),
        );
      }
    } finally {
      _runningTaskIds.remove(taskId);
      _taskCancelTokens.remove(taskId);
      await _persistNow();
      _schedule();
    }
  }

  Future<void> _downloadComic(String taskId) async {
    _assertTaskRunning(taskId);
    final task = _taskById(taskId);
    if (task == null) {
      throw _TaskCanceledException();
    }

    final apiClient = _ref.read(apiClientManagerProvider);

    final manifestToken = CancelToken();
    _registerCancelToken(taskId, manifestToken);

    List<dynamic> manifestRows;
    try {
      final response = await apiClient.get(
        '/api/comic/download/${task.comicId}',
        cancelToken: manifestToken,
      );
      if (response.statusCode != 200 || response.data is! List) {
        throw Exception('获取下载清单失败');
      }
      manifestRows = response.data as List<dynamic>;
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        _throwByTaskStatus(taskId);
      }
      rethrow;
    } finally {
      _unregisterCancelToken(taskId, manifestToken);
    }

    _assertTaskRunning(taskId);

    final chapters = <ChapterInfo>[];
    for (final row in manifestRows) {
      final chapter = ChapterInfo.fromJson(
        Map<String, dynamic>.from(row as Map),
      );
      final images = chapter.images
          .map((image) => Map<String, dynamic>.from(image))
          .toList();
      chapters.add(chapter.copyWith(images: images));
    }
    chapters.sort((a, b) => a.chapterIndex.compareTo(b.chapterIndex));

    final externalRoot = await IoService.externalStorageDir;
    final comicRootRelative = path.join('comics', task.comicName);
    await IoService.ensureDirExists(comicRootRelative);

    final pendingJobs = <_ImageDownloadJob>[];
    final chapterRemaining = <String, int>{};

    int totalImages = 0;
    int downloadedImages = 0;
    int completedChapters = 0;

    for (final chapter in chapters) {
      _assertTaskRunning(taskId);
      final chapterDirRelative = path.join(comicRootRelative, chapter.dirName);
      await IoService.ensureDirExists(chapterDirRelative);

      int missingInChapter = 0;
      for (final image in chapter.images) {
        totalImages++;
        final remotePath = image['path']?.toString() ?? '';
        final fileName = path.basename(remotePath);
        final relativePath = path.join(chapterDirRelative, fileName);
        final localPath = path.join(externalRoot.path, relativePath);

        final localFile = File(localPath);
        if (await localFile.exists() && await localFile.length() > 0) {
          image['path'] = localPath;
          downloadedImages++;
          continue;
        }

        missingInChapter++;
        pendingJobs.add(
          _ImageDownloadJob(
            chapterId: chapter.id,
            chapterName: chapter.dirName,
            remotePath: remotePath,
            relativePath: relativePath,
            localPath: localPath,
            imageRef: image,
          ),
        );
      }

      chapterRemaining[chapter.id] = missingInChapter;
      if (missingInChapter == 0) {
        completedChapters++;
      }
    }

    _updateTask(
      taskId,
      (old) => old.copyWith(
        totalChapters: chapters.length,
        completedChapters: completedChapters,
        totalImages: totalImages,
        downloadedImages: downloadedImages,
        currentChapterName: chapters.isNotEmpty ? chapters.first.dirName : '',
        clearErrorMessage: true,
        updatedAtMs: _nowMs,
      ),
    );

    if (pendingJobs.isNotEmpty) {
      var remainingJobs = pendingJobs;
      for (int round = 0; round <= _maxImageRetryRounds; round++) {
        _assertTaskRunning(taskId);
        if (remainingJobs.isEmpty) break;

        final failedThisRound = <_ImageDownloadJob>[];
        await _runWithConcurrency<_ImageDownloadJob>(
          items: remainingJobs,
          concurrency: _maxConcurrentImagesPerComic,
          action: (job) async {
            _assertTaskRunning(taskId);
            try {
              await _downloadImage(
                taskId: taskId,
                job: job,
                apiClient: apiClient,
              );

              downloadedImages++;
              final nextRemaining = (chapterRemaining[job.chapterId] ?? 1) - 1;
              chapterRemaining[job.chapterId] = nextRemaining;
              if (nextRemaining == 0) {
                completedChapters++;
              }

              _updateTask(
                taskId,
                (old) => old.copyWith(
                  downloadedImages: downloadedImages,
                  completedChapters: completedChapters,
                  currentChapterName: job.chapterName,
                  clearErrorMessage: true,
                  updatedAtMs: _nowMs,
                ),
              );
            } on _TaskPausedException {
              rethrow;
            } on _TaskCanceledException {
              rethrow;
            } catch (_) {
              failedThisRound.add(job);
            }
          },
        );

        remainingJobs = failedThisRound;
        if (remainingJobs.isNotEmpty && round < _maxImageRetryRounds) {
          await Future.delayed(Duration(seconds: 1 + round));
        }
      }

      if (remainingJobs.isNotEmpty) {
        throw Exception('仍有${remainingJobs.length}张图片下载失败');
      }
    }

    _assertTaskRunning(taskId);

    final chapterBox = _ref.read(chapterInfoBoxProvider);
    final comicBox = _ref.read(comicInfoBoxProvider);

    final oldChapterIds = chapterBox.values
        .where((chapter) => chapter.comicId == task.comicId)
        .map((chapter) => chapter.id)
        .toList();

    final chapterMap = {
      for (final chapter in chapters)
        chapter.id: chapter.copyWith(imageCount: chapter.images.length),
    };

    final newChapterIds = chapterMap.keys.toSet();
    final deleteChapterIds = oldChapterIds
        .where((chapterId) => !newChapterIds.contains(chapterId))
        .toList();

    if (deleteChapterIds.isNotEmpty) {
      await chapterBox.deleteAll(deleteChapterIds);
    }
    if (chapterMap.isNotEmpty) {
      await chapterBox.putAll(chapterMap);
    }

    var coverImage = task.coverImage;
    if (chapters.isNotEmpty && chapters.first.images.isNotEmpty) {
      coverImage =
          chapters.first.images.first['path']?.toString() ?? coverImage;
    }

    await comicBox.put(
      task.comicId,
      ComicInfo(
        id: task.comicId,
        comicName: task.comicName,
        coverImage: coverImage,
        chapterCount: chapters.length,
        imageCount: totalImages,
      ),
    );

    _updateTask(
      taskId,
      (old) => old.copyWith(
        status: ComicDownloadTaskStatus.completed,
        totalChapters: chapters.length,
        completedChapters: chapters.length,
        totalImages: totalImages,
        downloadedImages: totalImages,
        currentChapterName: chapters.isNotEmpty ? chapters.last.dirName : '',
        retryCount: 0,
        clearErrorMessage: true,
        clearNextRetryAtMs: true,
        updatedAtMs: _nowMs,
      ),
    );
  }

  Future<void> _downloadImage({
    required String taskId,
    required _ImageDownloadJob job,
    required ApiClient apiClient,
  }) async {
    final token = CancelToken();
    _registerCancelToken(taskId, token);

    try {
      final response = await apiClient.getBinary(
        '/static/${job.remotePath}',
        cancelToken: token,
      );
      if (response.statusCode != 200 || response.data == null) {
        throw Exception('图片下载失败');
      }
      await IoService.saveImageToExternalStorage(
        relativePath: job.relativePath,
        bytes: response.data!,
      );
      job.imageRef['path'] = job.localPath;
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        _throwByTaskStatus(taskId);
      }
      rethrow;
    } finally {
      _unregisterCancelToken(taskId, token);
    }
  }

  Future<void> _runWithConcurrency<T>({
    required List<T> items,
    required int concurrency,
    required Future<void> Function(T item) action,
  }) async {
    if (items.isEmpty) return;

    int index = 0;

    Future<void> worker() async {
      while (true) {
        if (index >= items.length) {
          return;
        }
        final current = items[index];
        index++;
        await action(current);
      }
    }

    final workerCount = min(concurrency, items.length);
    await Future.wait(List.generate(workerCount, (_) => worker()));
  }

  void _assertTaskRunning(String taskId) {
    final task = _taskById(taskId);
    if (task == null || task.status == ComicDownloadTaskStatus.canceled) {
      throw _TaskCanceledException();
    }
    if (task.status == ComicDownloadTaskStatus.paused) {
      throw _TaskPausedException();
    }
    if (task.status != ComicDownloadTaskStatus.running) {
      throw _TaskCanceledException();
    }
  }

  Never _throwByTaskStatus(String taskId) {
    final task = _taskById(taskId);
    if (task == null || task.status == ComicDownloadTaskStatus.canceled) {
      throw _TaskCanceledException();
    }
    if (task.status == ComicDownloadTaskStatus.paused) {
      throw _TaskPausedException();
    }
    throw _TaskCanceledException();
  }

  void _registerCancelToken(String taskId, CancelToken token) {
    final tokens = _taskCancelTokens.putIfAbsent(taskId, () => <CancelToken>[]);
    tokens.add(token);
  }

  void _unregisterCancelToken(String taskId, CancelToken token) {
    final tokens = _taskCancelTokens[taskId];
    if (tokens == null) return;
    tokens.remove(token);
    if (tokens.isEmpty) {
      _taskCancelTokens.remove(taskId);
    }
  }

  void _cancelTokensForTask(String taskId, {required String reason}) {
    final tokens = _taskCancelTokens[taskId];
    if (tokens == null) return;

    for (final token in tokens) {
      if (!token.isCancelled) {
        token.cancel(reason);
      }
    }
  }

  Future<void> _removeComicMeta(String comicId) async {
    final chapterBox = _ref.read(chapterInfoBoxProvider);
    final comicBox = _ref.read(comicInfoBoxProvider);
    final prefBox = _ref.read(comicPrefBoxProvider);

    final chapterIds = chapterBox.values
        .where((chapter) => chapter.comicId == comicId)
        .map((chapter) => chapter.id)
        .toList();

    if (chapterIds.isNotEmpty) {
      await chapterBox.deleteAll(chapterIds);
    }
    await comicBox.delete(comicId);
    await prefBox.delete(comicId);
  }

  ComicDownloadTask? _taskById(String taskId) {
    return _firstTaskWhere((task) => task.taskId == taskId);
  }

  ComicDownloadTask? _firstTaskWhere(
    bool Function(ComicDownloadTask task) test,
  ) {
    for (final task in state) {
      if (test(task)) return task;
    }
    return null;
  }

  void _updateTask(
    String taskId,
    ComicDownloadTask Function(ComicDownloadTask old) updater,
  ) {
    bool changed = false;
    final updated = <ComicDownloadTask>[];

    for (final task in state) {
      if (task.taskId == taskId) {
        updated.add(updater(task));
        changed = true;
      } else {
        updated.add(task);
      }
    }

    if (!changed) return;
    state = updated;
    _persistSoon();
  }

  void _persistSoon() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 400), () {
      unawaited(_persistNow());
    });
  }

  Future<void> _persistNow() async {
    _persistTimer?.cancel();
    _persistTimer = null;
    await PrefsService().prefs.setString(
      _prefsKey,
      jsonEncode(state.map((task) => task.toJson()).toList()),
    );
  }

  void _setupRetryTimer() {
    _retryTimer?.cancel();

    final waitingTasks = state
        .where(
          (task) =>
              task.status == ComicDownloadTaskStatus.retryWaiting &&
              task.nextRetryAtMs != null,
        )
        .toList();

    if (waitingTasks.isEmpty) return;

    waitingTasks.sort(
      (a, b) => (a.nextRetryAtMs ?? 0).compareTo(b.nextRetryAtMs ?? 0),
    );

    final nextRetryAt = waitingTasks.first.nextRetryAtMs!;
    final waitMs = max(0, nextRetryAt - _nowMs);
    _retryTimer = Timer(Duration(milliseconds: waitMs), _schedule);
  }

  int get _nowMs => DateTime.now().millisecondsSinceEpoch;

  @override
  void dispose() {
    _retryTimer?.cancel();
    _persistTimer?.cancel();

    for (final tokens in _taskCancelTokens.values) {
      for (final token in tokens) {
        if (!token.isCancelled) {
          token.cancel('dispose');
        }
      }
    }

    _taskCancelTokens.clear();
    _runningTaskIds.clear();
    super.dispose();
  }
}

class _ImageDownloadJob {
  const _ImageDownloadJob({
    required this.chapterId,
    required this.chapterName,
    required this.remotePath,
    required this.relativePath,
    required this.localPath,
    required this.imageRef,
  });

  final String chapterId;
  final String chapterName;
  final String remotePath;
  final String relativePath;
  final String localPath;
  final Map<String, dynamic> imageRef;
}

class _TaskPausedException implements Exception {}

class _TaskCanceledException implements Exception {}
