import 'dart:async';

import 'package:northstar/core/providers/ops/core_services_provider.dart';
import 'package:northstar/core/providers/ops/ops_settings_provider.dart';
import 'package:northstar/domain/ops/models/ops_overview.dart';
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
  int _lastInterval = 0;

  @override
  OpsOverviewState build() {
    ref.onDispose(() {
      _timer?.cancel();
    });

    ref.listen(opsSettingsControllerProvider, (previous, next) {
      if (_lastInterval != next.autoRefreshSeconds) {
        _restartTimer(next.autoRefreshSeconds);
      }
    });

    final initialInterval = ref.read(opsSettingsControllerProvider).autoRefreshSeconds;
    _restartTimer(initialInterval);

    Future<void>(() async {
      await refresh();
    });

    return OpsOverviewState.initial();
  }

  Future<void> refresh() async {
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
    }
  }

  void _restartTimer(int seconds) {
    _timer?.cancel();
    final safeSeconds = seconds <= 0 ? 300 : seconds;
    _lastInterval = safeSeconds;
    _timer = Timer.periodic(Duration(seconds: safeSeconds), (_) async {
      await refresh();
    });
    // 立即触发一次刷新，确保新间隔生效
    Future(() => refresh());
  }
}
