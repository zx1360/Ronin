import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:northstar/core/providers/ops/ops_settings_provider.dart';
import 'package:northstar/domain/comix/models/comix_models.dart';
import 'package:northstar/infrastructure/comix/comix_api_client.dart';

/// comix API 客户端单例。
final comixApiClientProvider = Provider<ComixApi>((ref) {
  final client = ComixApiClient();
  ref.onDispose(client.dispose);
  return client;
});

/// 已登记漫画列表（含下载进度与书库管理字段，单一数据源）。
final comixComicsProvider = FutureProvider<List<ComixComic>>((ref) {
  final settings = ref.watch(opsSettingsControllerProvider);
  return ref.watch(comixApiClientProvider).fetchComics(settings);
});

/// 任务面板状态。
class ComixBoardState {
  final List<ComixTask> tasks;
  final bool refreshing;
  final String? error;

  const ComixBoardState({
    this.tasks = const [],
    this.refreshing = false,
    this.error,
  });

  ComixBoardState copyWith({
    List<ComixTask>? tasks,
    bool? refreshing,
    String? error,
    bool clearError = false,
  }) {
    return ComixBoardState(
      tasks: tasks ?? this.tasks,
      refreshing: refreshing ?? this.refreshing,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// 任务面板控制器：管理任务列表刷新与启动/中断。
///
/// 任务详情（含 result 与完整日志）按 task_id 缓存在 [_details] 中，
/// 任务结束后结果与日志依然可见。
///
/// 轮询由本控制器自管，且**按需启停**：只有在"有运行中任务"或"刚提交、尚未在
/// 列表中出现"时才定时刷新，全部落定后立即停表；页面不在前台时同样停表。
class ComixBoardNotifier extends Notifier<ComixBoardState> {
  /// 轮询间隔（测试可调小，正式运行固定 2s）。
  static Duration pollInterval = const Duration(seconds: 2);

  final Map<String, ComixTask> _details = <String, ComixTask>{};

  /// 已出现在后端列表里的 task_id：用于识别"已提交但列表尚未反映"的任务。
  final Set<String> _seenIds = <String>{};

  /// 连续多少轮刷新仍没看到待观察的任务。用于兜底：任务若始终不出现
  /// （后端已裁剪、提交被吞），不能让轮询永远跑下去。
  int _pendingGraceRounds = 0;

  Timer? _timer;
  bool _refreshing = false;
  bool _pageActive = false;

  /// 已见到"结果"的任务数：用于识别任务落定，落定后刷新漫画库的下载计数。
  int _resultCount = 0;

  @override
  ComixBoardState build() {
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
    });
    return const ComixBoardState();
  }

  /// 页面进入/离开时切换轮询开关；离开后不再产生任何后台请求。
  void setPageActive(bool active) {
    _pageActive = active;
    if (!active) _pendingGraceRounds = 0;
    _syncPolling();
  }

  /// 刷新任务列表；运行中的任务与被缓存的详情合并后再上报。
  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    state = state.copyWith(refreshing: true, clearError: true);
    try {
      final settings = ref.read(opsSettingsControllerProvider);
      final client = ref.read(comixApiClientProvider);
      final tasks = await client.fetchTasks(settings);

      final merged = <ComixTask>[];
      for (final task in tasks) {
        _seenIds.add(task.id);
        final cached = _details[task.id];
        // 运行中：必须拉最新详情（实时日志）；
        // 首次见到且已结束的非运行任务：也拉一次详情，补齐 result 与日志。
        final needDetail =
            task.isRunning ||
            (cached == null && !task.isRunning) ||
            (cached != null && cached.isRunning && !task.isRunning);
        if (!needDetail) {
          merged.add(cached ?? task);
          continue;
        }
        try {
          final detail = await client.fetchTask(settings, task.id);
          _details[task.id] = detail;
          merged.add(detail);
        } catch (_) {
          // 详情拉取失败时退回列表快照（列表已带 result），并保留已有缓存
          if (cached != null) {
            merged.add(cached.copyWith(status: task.status));
          } else {
            merged.add(task);
          }
        }
      }
      // 清理已被后端裁剪掉的任务缓存，避免无界增长
      final aliveIds = tasks.map((t) => t.id).toSet();
      _details.removeWhere((id, _) => !aliveIds.contains(id));
      _seenIds.removeWhere((id) => !aliveIds.contains(id));

      state = state.copyWith(tasks: merged, refreshing: false);

      // 有任务落定（结束或新结果出现）就刷新漫画库：下载计数由服务端聚合，
      // 不刷新会长期停在旧值。
      final results = merged.where((t) => t.result != null).length;
      if (results > _resultCount) {
        ref.invalidate(comixComicsProvider);
      }
      _resultCount = results;
    } catch (e) {
      state = state.copyWith(refreshing: false, error: e.toString());
    } finally {
      _refreshing = false;
      _syncPolling();
    }
  }

  /// 启动一个异步任务并刷新面板，返回 task_id。
  Future<String> startTask(String endpoint, Map<String, dynamic> body) async {
    final settings = ref.read(opsSettingsControllerProvider);
    final client = ref.read(comixApiClientProvider);
    final taskId = await client.startTask(settings, endpoint, body);
    _trackSubmitted(<String>[taskId]);
    await refresh();
    return taskId;
  }

  /// 登记一批外部提交（URL 批量下载走 `/download-url`，不经 [startTask]）
  /// 的任务：即使它们在首次列表请求前就结束，轮询也不会过早停表。
  Future<void> trackSubmitted(List<String> taskIds) async {
    _trackSubmitted(taskIds);
    await refresh();
  }

  void _trackSubmitted(List<String> taskIds) {
    for (final id in taskIds) {
      if (id.isEmpty) continue;
      _details.putIfAbsent(
        id,
        () => ComixTask(
          id: id,
          name: '',
          command: '',
          status: ComixTaskStatus.running,
          pid: 0,
        ),
      );
    }
  }

  /// 中断运行中的任务。
  Future<void> stopTask(String taskId) async {
    final settings = ref.read(opsSettingsControllerProvider);
    await ref.read(comixApiClientProvider).stopTask(settings, taskId);
    await refresh();
  }

  /// 根据当前状态决定是否继续轮询：没有可观察的任务就不再发请求。
  void _syncPolling() {
    if (_hasPendingSubmission()) {
      _pendingGraceRounds++;
    } else {
      _pendingGraceRounds = 0;
    }
    // 连续多轮都没看到已提交的任务（后端已裁剪/被吞）就不再等待。
    final pendingTooLong = _pendingGraceRounds > 15;

    final needPoll =
        _pageActive &&
        !pendingTooLong &&
        (state.tasks.any((t) => t.isRunning) || _hasPendingSubmission());
    if (needPoll) {
      _timer ??= Timer.periodic(pollInterval, (_) => unawaited(refresh()));
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  /// 已提交但还没出现在任务列表里的任务（短任务可能在首次列表请求前就跑完）。
  bool _hasPendingSubmission() =>
      _details.keys.any((id) => !_seenIds.contains(id));
}

final comixBoardProvider =
    NotifierProvider<ComixBoardNotifier, ComixBoardState>(
      ComixBoardNotifier.new,
    );
