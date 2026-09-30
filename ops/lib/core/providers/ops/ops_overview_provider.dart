import 'dart:async';

import 'package:northstar/core/providers/ops/core_services_provider.dart';
import 'package:northstar/core/providers/ops/ops_settings_provider.dart';
import 'package:northstar/core/providers/ops/runtime_process_provider.dart';
import 'package:northstar/domain/ops/models/ops_overview.dart';
import 'package:northstar/domain/ops/models/runtime_process_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ops_overview_provider.g.dart';

class OpsOverviewState {
  final bool loading;
  final bool online;
  final OpsOverview? overview;
  final String? errorMessage;
  final DateTime? lastUpdatedAt;

  const OpsOverviewState({
    required this.loading,
    required this.online,
    required this.overview,
    required this.errorMessage,
    required this.lastUpdatedAt,
  });

  factory OpsOverviewState.initial() {
    return const OpsOverviewState(
      loading: false,
      online: false,
      overview: null,
      errorMessage: null,
      lastUpdatedAt: null,
    );
  }

  OpsOverviewState copyWith({
    bool? loading,
    bool? online,
    OpsOverview? overview,
    String? errorMessage,
    DateTime? lastUpdatedAt,
    bool clearError = false,
  }) {
    return OpsOverviewState(
      loading: loading ?? this.loading,
      online: online ?? this.online,
      overview: overview ?? this.overview,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }
}

@Riverpod(keepAlive: true)
class OpsOverviewController extends _$OpsOverviewController {
  Timer? _timer;
  Timer? _serviceTimer;
  int _lastInterval = 0;
  bool _refreshing = false;

  /// 上一轮处于运行中的任务：用于在本应用启动/停止子进程后自动重新取值。
  Set<String> _runningTasks = <String>{};

  @override
  OpsOverviewState build() {
    ref.onDispose(() {
      _timer?.cancel();
      _serviceTimer?.cancel();
    });

    // 配置变更（地址/密钥/轮询间隔）后必须重新取值：否则页面会一直显示旧地址
    // 的数据，或继续按旧间隔轮询。
    ref.listen(opsSettingsControllerProvider, (previous, next) {
      final endpointChanged = previous?.apiBaseUrl != next.apiBaseUrl ||
          previous?.apiKey != next.apiKey;
      if (_lastInterval != next.autoRefreshSeconds) {
        // _restartTimer 内部会立即刷新一次，覆盖 endpointChanged 的情况
        _restartTimer(next.autoRefreshSeconds);
      } else if (endpointChanged) {
        state = OpsOverviewState.initial();
        _scheduleImmediateRefresh();
      }
    });

    // 由本应用启动 Monarch 时，进程就绪前既没有数据、首次请求也必然失败。
    // 启动后按短间隔重试一段时间，避免用户手动刷新。
    ref.listen(runtimeProcessControllerProvider, (previous, next) {
      final running = next.runtimes.values
          .where((r) =>
              r.status == RuntimeStatus.running ||
              r.status == RuntimeStatus.starting)
          .map((r) => r.taskId)
          .toSet();

      final started = running.difference(_runningTasks);
      final finished = _runningTasks.difference(running);
      _runningTasks = running;

      if (started.isNotEmpty) {
        _watchUntilOnline(attempts: 10);
      } else if (finished.isNotEmpty) {
        // 服务已停止：稍等端口状态稳定后刷新一次，如实显示离线
        _serviceTimer?.cancel();
        _serviceTimer =
            Timer(const Duration(seconds: 2), () => unawaited(refresh()));
      }
    });

    _restartTimer(ref.read(opsSettingsControllerProvider).autoRefreshSeconds);

    return OpsOverviewState.initial();
  }

  /// 服务启动后轮询直到拿到数据（上限 [attempts] 次，每次 2s）。
  void _watchUntilOnline({required int attempts}) {
    _serviceTimer?.cancel();
    if (attempts <= 0 || state.online) return;
    _serviceTimer = Timer(const Duration(seconds: 2), () async {
      await refresh();
      if (!state.online) {
        _watchUntilOnline(attempts: attempts - 1);
      }
    });
  }

  Future<void> refresh() async {
    // 定时轮询与手动刷新可能重叠：并发请求既浪费也可能让旧响应覆盖新结果。
    if (_refreshing) return;
    _refreshing = true;
    state = state.copyWith(loading: true, clearError: true);

    final settings = ref.read(opsSettingsControllerProvider);
    final client = ref.read(opsApiClientProvider);

    try {
      final overview = await client.fetchOverview(settings);
      state = state.copyWith(
        loading: false,
        online: true,
        overview: overview,
        clearError: true,
        lastUpdatedAt: DateTime.now(),
      );
    } catch (error) {
      state = state.copyWith(
        loading: false,
        online: false,
        errorMessage: error.toString(),
      );
    } finally {
      _refreshing = false;
    }
  }

  void _restartTimer(int seconds) {
    _timer?.cancel();
    final safeSeconds = seconds <= 0 ? 300 : seconds;
    _lastInterval = safeSeconds;
    _timer = Timer.periodic(Duration(seconds: safeSeconds), (_) async {
      await refresh();
    });
    // 立即取一次数据，避免等待首个轮询周期
    _scheduleImmediateRefresh();
  }

  /// 把"立即刷新"排到当前帧之后。
  ///
  /// [build] 内部直接调用 refresh 会写状态，而此刻 provider 的状态尚未挂载
  /// （Riverpod 抛 "Tried to read the state of an uninitialized provider"），
  /// 表现为启动后仪表盘永远拿不到数据。
  void _scheduleImmediateRefresh() {
    Future(() => unawaited(refresh()));
  }
}
