import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:northstar/core/providers/ops/ops_settings_provider.dart';
import 'package:northstar/domain/ai/models/ai_models.dart';
import 'package:northstar/infrastructure/ai/ai_api_client.dart';

/// AI API 客户端单例。
final aiApiClientProvider = Provider<AiApiClient>((ref) {
  final client = AiApiClient();
  ref.onDispose(client.dispose);
  return client;
});

/// AI 处理层看板状态。
class AiBoardState {
  final AiStatus? status;
  final bool loading;
  final bool busy;
  final String? error;
  final String? notice;

  const AiBoardState({
    this.status,
    this.loading = false,
    this.busy = false,
    this.error,
    this.notice,
  });

  AiBoardState copyWith({
    AiStatus? status,
    bool? loading,
    bool? busy,
    String? error,
    String? notice,
    bool clearMessages = false,
  }) {
    return AiBoardState(
      status: status ?? this.status,
      loading: loading ?? this.loading,
      busy: busy ?? this.busy,
      error: clearMessages ? null : (error ?? this.error),
      notice: clearMessages ? null : (notice ?? this.notice),
    );
  }
}

/// AI 看板控制器：状态刷新、入队/重试/中断、模型进程启停。
///
/// 轮询按需启停：仅当页面可见且"确实有活可看"（有排队/运行中的任务，
/// 或某个模型进程正在运行）时才定时刷新；否则立即停表。
class AiBoardNotifier extends Notifier<AiBoardState> {
  /// 轮询间隔（2s：批次完成与进程退出都希望尽快反映到界面）。
  static Duration pollInterval = const Duration(seconds: 2);

  Timer? _timer;
  bool _pageActive = false;
  bool _refreshing = false;

  @override
  AiBoardState build() {
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
    });
    return const AiBoardState();
  }

  void setPageActive(bool active) {
    _pageActive = active;
    if (active) {
      unawaited(refresh());
    }
    _syncPolling();
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final settings = ref.read(opsSettingsControllerProvider);
      final status = await ref.read(aiApiClientProvider).fetchStatus(settings);
      state = state.copyWith(status: status, loading: false, clearMessages: true);
      _syncPolling();
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
      _syncPolling();
    } finally {
      _refreshing = false;
    }
  }

  /// 执行一次带反馈的操作（入队/重试/启停模型等），完成后刷新状态。
  Future<bool> run(String successNotice, Future<void> Function() action) async {
    state = state.copyWith(busy: true, clearMessages: true);
    try {
      final settings = ref.read(opsSettingsControllerProvider);
      await action();
      state = state.copyWith(busy: false, notice: successNotice);
      final status = await ref.read(aiApiClientProvider).fetchStatus(settings);
      state = state.copyWith(status: status);
      ref.invalidate(aiPersonsProvider);
      _syncPolling();
      return true;
    } catch (e) {
      state = state.copyWith(busy: false, error: e.toString());
      return false;
    }
  }

  void clearMessages() {
    state = state.copyWith(clearMessages: true);
  }

  /// 是否还有值得持续观察的活动。
  bool _hasActivity() {
    final status = state.status;
    if (status == null) return false;
    // 暂停期间不会有新进展，但仍要观察"批次是否已真正停下"
    if (status.paused) return status.lastRun?.running == true;
    if (status.pendingTotal > 0) return true;
    if (status.lastRun?.running == true) return true;
    if (status.ollama.ownedServer) return true;
    return status.capabilities.any((c) => c.sidecar?.running == true);
  }

  void _syncPolling() {
    final needPoll = _pageActive && _hasActivity();
    if (needPoll) {
      _timer ??= Timer.periodic(pollInterval, (_) => unawaited(refresh()));
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }
}

final aiBoardProvider = NotifierProvider<AiBoardNotifier, AiBoardState>(
  AiBoardNotifier.new,
);

/// 人物分组列表（写操作后由看板 invalidate）。
final aiPersonsProvider = FutureProvider<List<AiPerson>>((ref) {
  final settings = ref.watch(opsSettingsControllerProvider);
  return ref.watch(aiApiClientProvider).fetchPersons(settings);
});

/// 任务列表（按能力/状态过滤；重试后整体 invalidate 即可刷新）。
final aiJobsProvider =
    FutureProvider.family<({List<AiJob> jobs, int total}),
        ({String capability, String status})>((ref, filter) {
  final settings = ref.watch(opsSettingsControllerProvider);
  return ref.watch(aiApiClientProvider).fetchJobs(
        settings,
        capability: filter.capability,
        status: filter.status,
        limit: 200,
      );
});

/// 检索状态。
class AiSearchState {
  final String query;
  final String mode;
  final bool loading;
  final AiSearchResult result;
  final String? error;

  const AiSearchState({
    this.query = '',
    this.mode = 'auto',
    this.loading = false,
    this.result = AiSearchResult.empty,
    this.error,
  });

  AiSearchState copyWith({
    String? query,
    String? mode,
    bool? loading,
    AiSearchResult? result,
    String? error,
    bool clearError = false,
  }) {
    return AiSearchState(
      query: query ?? this.query,
      mode: mode ?? this.mode,
      loading: loading ?? this.loading,
      result: result ?? this.result,
      error: clearError ? null : (error ?? this.error),
    );
  }

  bool get isEmpty => result.hits.isEmpty;
}

/// 检索控制器：文本搜图（语义/关键词/混合）与以图搜图（相似媒体）。
class AiSearchNotifier extends Notifier<AiSearchState> {
  @override
  AiSearchState build() => const AiSearchState();

  void setMode(String mode) => state = state.copyWith(mode: mode);

  Future<void> search(String query) async {
    state = state.copyWith(query: query, loading: true, clearError: true);
    try {
      final settings = ref.read(opsSettingsControllerProvider);
      final result = await ref.read(aiApiClientProvider).search(
            settings,
            query: query,
            mode: state.mode,
          );
      state = state.copyWith(loading: false, result: result);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  /// 以图搜图：以库内某张图为查询。
  Future<void> similarTo(String mediaId) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final settings = ref.read(opsSettingsControllerProvider);
      final result =
          await ref.read(aiApiClientProvider).similar(settings, mediaId);
      state = state.copyWith(
        loading: false,
        result: result,
        query: '与所选图片相似',
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void clear() => state = const AiSearchState();
}

final aiSearchProvider = NotifierProvider<AiSearchNotifier, AiSearchState>(
  AiSearchNotifier.new,
);
