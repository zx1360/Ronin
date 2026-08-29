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

