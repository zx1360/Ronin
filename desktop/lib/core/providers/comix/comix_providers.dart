import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:northstar/core/providers/ops/ops_settings_provider.dart';
import 'package:northstar/domain/comix/models/comix_models.dart';
import 'package:northstar/infrastructure/comix/comix_api_client.dart';

/// comix API 客户端单例。
final comixApiClientProvider = Provider<ComixApiClient>((ref) {
  final client = ComixApiClient();
  ref.onDispose(client.dispose);
  return client;
});

/// comix 集成配置（只读展示；settings 变化时自动刷新）。
final comixConfigProvider = FutureProvider<ComixConfig>((ref) {
  final settings = ref.watch(opsSettingsControllerProvider);
  return ref.watch(comixApiClientProvider).fetchConfig(settings);
});

/// 站点列表。
final comixSitesProvider = FutureProvider<List<ComixSite>>((ref) {
  final settings = ref.watch(opsSettingsControllerProvider);
  return ref.watch(comixApiClientProvider).fetchSites(settings);
});

/// 已登记漫画列表。
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

  bool get hasRunningTasks => tasks.any((t) => t.isRunning);

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
/// 任务详情（含 result 与完整日志）按 task_id 缓存在 [_details] 中：
/// 文本结果与日志在任务结束后依然可见（旧实现只在 isRunning 时拉详情，
/// 任务一结束结果与日志就同时消失，用户无法确认下载/追更到底做了什么）。
class ComixBoardNotifier extends Notifier<ComixBoardState> {
  final Map<String, ComixTask> _details = <String, ComixTask>{};

  @override
  ComixBoardState build() {
    return const ComixBoardState();
  }

  /// 刷新任务列表；运行中的任务与被缓存的详情合并后再上报。
  Future<void> refresh() async {
    state = state.copyWith(refreshing: true, clearError: true);
    try {
      final settings = ref.read(opsSettingsControllerProvider);
      final client = ref.read(comixApiClientProvider);
      final tasks = await client.fetchTasks(settings);

      final merged = <ComixTask>[];
      for (final task in tasks) {
        final cached = _details[task.id];
        // 运行中：必须拉最新详情（实时日志）；
        // 首次见到且已结束的非运行任务：也拉一次详情，补齐 result 与日志。
        final needDetail = task.isRunning ||
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

      state = state.copyWith(tasks: merged, refreshing: false);
    } catch (e) {
      state = state.copyWith(refreshing: false, error: e.toString());
    }
  }

  /// 启动一个异步任务并刷新面板，返回 task_id。
  Future<String> startTask(String endpoint, Map<String, dynamic> body) async {
    final settings = ref.read(opsSettingsControllerProvider);
    final client = ref.read(comixApiClientProvider);
    final taskId = await client.startTask(settings, endpoint, body);
    await refresh();
    return taskId;
  }

  /// 中断运行中的任务。
  Future<void> stopTask(String taskId) async {
    final settings = ref.read(opsSettingsControllerProvider);
    await ref.read(comixApiClientProvider).stopTask(settings, taskId);
    await refresh();
  }
}

final comixBoardProvider = NotifierProvider<ComixBoardNotifier, ComixBoardState>(
  ComixBoardNotifier.new,
);

