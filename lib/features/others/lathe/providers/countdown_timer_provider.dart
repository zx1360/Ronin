import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../models/countdown_timer_model.dart';
import '../services/lathe_notification_service.dart';
import '../services/lathe_foreground_service.dart';

part 'countdown_timer_provider.g.dart';

/// 倒计时器列表状态
@immutable
class CountdownTimersState {
  final List<CountdownTimerModel> timers;
  final bool isForegroundServiceRunning;

  const CountdownTimersState({
    this.timers = const [],
    this.isForegroundServiceRunning = false,
  });

  CountdownTimersState copyWith({
    List<CountdownTimerModel>? timers,
    bool? isForegroundServiceRunning,
  }) {
    return CountdownTimersState(
      timers: timers ?? this.timers,
      isForegroundServiceRunning: isForegroundServiceRunning ?? this.isForegroundServiceRunning,
    );
  }

  /// 是否有正在运行的倒计时
  bool get hasRunningTimers => timers.any((t) => t.isRunning);
}

/// 倒计时器管理Provider
@riverpod
class CountdownTimers extends _$CountdownTimers {
  Timer? _tickTimer;
  final _uuid = const Uuid();

  @override
  CountdownTimersState build() {
    ref.onDispose(() {
      _tickTimer?.cancel();
      // 页面销毁时停止前台服务
      LatheForegroundService.instance.stopService();
    });
    return const CountdownTimersState();
  }

  /// 添加新的倒计时器
  void addTimer({
    required String name,
    required int totalSeconds,
  }) {
    final timer = CountdownTimerModel(
      id: _uuid.v4(),
      name: name,
      totalSeconds: totalSeconds.clamp(1, 3600), // 最大60分钟
      remainingSeconds: totalSeconds.clamp(1, 3600),
      status: CountdownTimerStatus.idle,
    );

    state = state.copyWith(
      timers: [...state.timers, timer],
    );
  }

  /// 删除倒计时器
  void removeTimer(String id) {
    final newTimers = state.timers.where((t) => t.id != id).toList();
    state = state.copyWith(timers: newTimers);
    _checkAndUpdateForegroundService();
  }

  /// 修改倒计时器
  void updateTimer({
    required String id,
    String? name,
    int? totalSeconds,
  }) {
    final index = state.timers.indexWhere((t) => t.id == id);
    if (index == -1) return;

    final timer = state.timers[index];
    // 只有在空闲状态才能修改时间
    if (timer.status != CountdownTimerStatus.idle && totalSeconds != null) {
      return;
    }

    final updatedTimer = timer.copyWith(
      name: name,
      totalSeconds: totalSeconds?.clamp(1, 3600),
      remainingSeconds: totalSeconds?.clamp(1, 3600) ?? timer.remainingSeconds,
    );

    final newTimers = List<CountdownTimerModel>.from(state.timers);
    newTimers[index] = updatedTimer;
    state = state.copyWith(timers: newTimers);
  }

  /// 开始倒计时
  Future<void> startTimer(String id) async {
    final index = state.timers.indexWhere((t) => t.id == id);
    if (index == -1) return;

    final timer = state.timers[index];
    if (timer.status == CountdownTimerStatus.running) return;

    final now = DateTime.now();
    final updatedTimer = timer.copyWith(
      status: CountdownTimerStatus.running,
      remainingSeconds: timer.totalSeconds,
      startTime: now,
      lastUpdateTime: now,
    );

    final newTimers = List<CountdownTimerModel>.from(state.timers);
    newTimers[index] = updatedTimer;
    state = state.copyWith(timers: newTimers);

    _startTickTimer();
    await _checkAndUpdateForegroundService();
  }

  /// 停止倒计时（恢复到未开启状态）
  Future<void> stopTimer(String id) async {
    final index = state.timers.indexWhere((t) => t.id == id);
    if (index == -1) return;

    final timer = state.timers[index];
    final updatedTimer = timer.copyWith(
      status: CountdownTimerStatus.idle,
      remainingSeconds: timer.totalSeconds,
      startTime: null,
      lastUpdateTime: null,
    );

    final newTimers = List<CountdownTimerModel>.from(state.timers);
    newTimers[index] = updatedTimer;
    state = state.copyWith(timers: newTimers);

    await _checkAndUpdateForegroundService();
  }

  /// 重新开始倒计时（从完成状态开始新一轮）
  Future<void> restartTimer(String id) async {
    final index = state.timers.indexWhere((t) => t.id == id);
    if (index == -1) return;

    final timer = state.timers[index];
    if (timer.status != CountdownTimerStatus.completed) return;

    final now = DateTime.now();
    final updatedTimer = timer.copyWith(
      status: CountdownTimerStatus.running,
      remainingSeconds: timer.totalSeconds,
      startTime: now,
      lastUpdateTime: now,
    );

    final newTimers = List<CountdownTimerModel>.from(state.timers);
    newTimers[index] = updatedTimer;
    state = state.copyWith(timers: newTimers);

    _startTickTimer();
    await _checkAndUpdateForegroundService();
  }

  /// 启动计时器tick
  void _startTickTimer() {
    if (_tickTimer?.isActive ?? false) return;
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  /// 每秒tick处理
  void _onTick() {
    final now = DateTime.now();
    bool hasRunningTimers = false;
    bool hasCompletedThisTick = false;
    List<String> completedTimerNames = [];

    final newTimers = state.timers.map((timer) {
      if (timer.status != CountdownTimerStatus.running) {
        return timer;
      }

      hasRunningTimers = true;

      // 计算实际经过的时间（处理息屏后的时间补偿）
      int elapsedSeconds = 1;
      if (timer.lastUpdateTime != null) {
        elapsedSeconds = now.difference(timer.lastUpdateTime!).inSeconds;
        if (elapsedSeconds < 1) elapsedSeconds = 1;
      }

      final newRemaining = (timer.remainingSeconds - elapsedSeconds).clamp(0, timer.totalSeconds);

      if (newRemaining <= 0) {
        // 倒计时完成
        hasCompletedThisTick = true;
        completedTimerNames.add(timer.name);
        return timer.copyWith(
          status: CountdownTimerStatus.completed,
          remainingSeconds: 0,
          lastUpdateTime: now,
        );
      }

      return timer.copyWith(
        remainingSeconds: newRemaining,
        lastUpdateTime: now,
      );
    }).toList();

    state = state.copyWith(timers: newTimers);

    // 发送通知
    if (hasCompletedThisTick) {
      for (final name in completedTimerNames) {
        LatheNotificationService.instance.showTimerCompletedNotification(name);
      }
    }

    // 如果没有运行中的计时器，停止tick
    if (!hasRunningTimers && !state.hasRunningTimers) {
      _tickTimer?.cancel();
      _tickTimer = null;
      _checkAndUpdateForegroundService();
    }
  }

  /// 检查并更新前台服务状态
  Future<void> _checkAndUpdateForegroundService() async {
    if (state.hasRunningTimers) {
      if (!state.isForegroundServiceRunning) {
        await LatheForegroundService.instance.startService();
        state = state.copyWith(isForegroundServiceRunning: true);
      }
      // 更新前台服务通知
      _updateForegroundNotification();
    } else {
      if (state.isForegroundServiceRunning) {
        await LatheForegroundService.instance.stopService();
        state = state.copyWith(isForegroundServiceRunning: false);
      }
    }
  }

  /// 更新前台服务通知内容
  void _updateForegroundNotification() {
    final runningTimers = state.timers.where((t) => t.isRunning).toList();
    if (runningTimers.isEmpty) return;

    final text = runningTimers
        .map((t) => '${t.name}: ${t.formattedRemainingTime}')
        .join(' | ');
    LatheForegroundService.instance.updateNotification(
      title: '倒计时运行中',
      text: text,
    );
  }

  /// 页面恢复时同步状态（处理后台恢复）
  void syncOnResume() {
    if (!state.hasRunningTimers) return;
    _onTick(); // 立即执行一次tick以同步时间
    _startTickTimer(); // 确保计时器在运行
  }
}
