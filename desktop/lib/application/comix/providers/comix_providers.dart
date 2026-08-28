import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:northstar/application/ops/providers/ops_settings_provider.dart';
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
class ComixBoardNotifier extends Notifier<ComixBoardState> {
  @override
  ComixBoardState build() {
    return const ComixBoardState();
  }

  /// 刷新任务列表；运行中的任务同时拉取详情（含实时日志）。
  Future<void> refresh() async {
    state = state.copyWith(refreshing: true, clearError: true);
    try {
      final settings = ref.read(opsSettingsControllerProvider);
      final client = ref.read(comixApiClientProvider);
      final tasks = await client.fetchTasks(settings);

      final detailed = <ComixTask>[];
      for (final task in tasks) {
        if (task.isRunning) {
          try {
            detailed.add(await client.fetchTask(settings, task.id));
          } catch (_) {
            detailed.add(task);
          }
        } else {
          detailed.add(task);
        }
      }
      state = state.copyWith(tasks: detailed, refreshing: false);
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

// ---------------------------------------------------------------------------
// 搜索状态（提取自页面，便于 Tab 切换后状态保留与轮询收集结果）
// ---------------------------------------------------------------------------

/// 搜索状态。
class ComixSearchState {
  final String keyword;
  final String? siteFilter;
  final List<ComixCandidate> candidates;
  final bool searching;
  final String? error;
  final String? taskId;

  const ComixSearchState({
    this.keyword = '',
    this.siteFilter,
    this.candidates = const [],
    this.searching = false,
    this.error,
    this.taskId,
  });

  ComixSearchState copyWith({
    String? keyword,
    String? siteFilter,
    bool clearSiteFilter = false,
    List<ComixCandidate>? candidates,
    bool? searching,
    String? error,
    bool clearError = false,
    String? taskId,
    bool clearTaskId = false,
  }) {
    return ComixSearchState(
      keyword: keyword ?? this.keyword,
      siteFilter: clearSiteFilter ? null : (siteFilter ?? this.siteFilter),
      candidates: candidates ?? this.candidates,
      searching: searching ?? this.searching,
      error: clearError ? null : (error ?? this.error),
      taskId: clearTaskId ? null : (taskId ?? this.taskId),
    );
  }
}

/// 搜索控制器：提交搜索任务、站点过滤、收集任务结果。
class ComixSearchNotifier extends Notifier<ComixSearchState> {
  @override
  ComixSearchState build() {
    return const ComixSearchState();
  }

  Future<void> startSearch(String keyword) async {
    state = state.copyWith(
      keyword: keyword,
      searching: true,
      clearError: true,
      candidates: const [],
    );
    try {
      final taskId = await ref
          .read(comixBoardProvider.notifier)
          .startTask('search', {'name': keyword});
      state = state.copyWith(taskId: taskId);
    } catch (e) {
      state = state.copyWith(searching: false, error: e.toString());
    }
  }

  void setSiteFilter(String? site) {
    state = state.copyWith(siteFilter: site);
  }

  /// 由页面轮询调用：搜索任务结束后取回候选结果。
  Future<void> collectResult() async {
    final taskId = state.taskId;
    if (taskId == null) return;

    final board = ref.read(comixBoardProvider);
    var running = false;
    for (final task in board.tasks) {
      if (task.id == taskId && task.isRunning) {
        running = true;
        break;
      }
    }
    if (running) return;

    state = state.copyWith(clearTaskId: true);
    try {
      final settings = ref.read(opsSettingsControllerProvider);
      final client = ref.read(comixApiClientProvider);
      final detail = await client.fetchTask(settings, taskId);
      final result = detail.result;
      if (result != null && result['ok'] == true) {
        final data = result['data'];
        final list = data is Map<String, dynamic> ? data['candidates'] : null;
        state = state.copyWith(
          searching: false,
          candidates: list is List
              ? list
                    .whereType<Map<String, dynamic>>()
                    .map(ComixCandidate.fromJson)
                    .toList()
              : const [],
          clearError: true,
        );
      } else {
        state = state.copyWith(
          searching: false,
          candidates: const [],
          error: (result?['error'] as String?) ?? detail.error ?? '搜索失败',
        );
      }
    } catch (e) {
      state = state.copyWith(searching: false, error: e.toString());
    }
  }
}

final comixSearchProvider =
    NotifierProvider<ComixSearchNotifier, ComixSearchState>(
      ComixSearchNotifier.new,
    );
