import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/storage/hive_service.dart';
import '../models/countdown_timer_model.dart';
import '../services/lathe_notification_service.dart';

part 'countdown_timer_provider.g.dart';

/// 倒计时器列表状态
@immutable
class CountdownTimersState {
  final List<CountdownTimerModel> timers;
  final bool isInitialized;

  const CountdownTimersState({
    this.timers = const [],
    this.isInitialized = false,
  });

  CountdownTimersState copyWith({
    List<CountdownTimerModel>? timers,
    bool? isInitialized,
  }) {
    return CountdownTimersState(
      timers: timers ?? this.timers,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }

  /// 是否有正在运行的倒计时
  bool get hasRunningTimers => timers.any((t) => t.isRunning);
}

/// 倒计时器管理Provider (keepAlive: true 保证在应用内全程存活)
@Riverpod(keepAlive: true)
class CountdownTimers extends _$CountdownTimers {
  Timer? _tickTimer;
  final _uuid = const Uuid();
  Box<CountdownTimerModel>? _box;

  Box<CountdownTimerModel> get _timerBox {
    _box ??= Hive.box<CountdownTimerModel>(HiveService.countdownTimerBoxName);
    return _box!;
  }

  @override
  CountdownTimersState build() {
    ref.onDispose(() {
      _tickTimer?.cancel();
    });
    
    // 使用 Future.microtask 延迟加载，等待 build 完成后再执行
    Future.microtask(_loadFromHive);
    
    return const CountdownTimersState();
  }

  /// 从Hive加载倒计时数据
  Future<void> _loadFromHive() async {
    final timers = _timerBox.values.toList();
    
    // 检查是否有运行中的计时器需要恢复
    final now = DateTime.now();
    final restoredTimers = timers.map((timer) {
      if (timer.status == CountdownTimerStatus.running && timer.lastUpdateTime != null) {
        // 计算离线期间经过的时间
        final elapsedSeconds = now.difference(timer.lastUpdateTime!).inSeconds;
        final newRemaining = (timer.remainingSeconds - elapsedSeconds).clamp(0, timer.totalSeconds);
        
        if (newRemaining <= 0) {
          // 倒计时已完成
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
      }
      return timer;
    }).toList();
    
    state = CountdownTimersState(
      timers: restoredTimers,
      isInitialized: true,
    );
    
    // 如果有运行中的计时器，启动tick
    if (state.hasRunningTimers) {
      _startTickTimer();
    }
    
    // 保存恢复后的状态
    await _saveAllToHive();
  }

  /// 保存所有倒计时到Hive
  Future<void> _saveAllToHive() async {
    await _timerBox.clear();
    for (final timer in state.timers) {
      await _timerBox.put(timer.id, timer);
    }
  }

  /// 保存单个倒计时到Hive
  Future<void> _saveTimerToHive(CountdownTimerModel timer) async {
    await _timerBox.put(timer.id, timer);
  }

  /// 从Hive删除倒计时
  Future<void> _deleteTimerFromHive(String id) async {
    await _timerBox.delete(id);
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
    
    _saveTimerToHive(timer);
  }

  /// 删除倒计时器
  void removeTimer(String id) {
    final newTimers = state.timers.where((t) => t.id != id).toList();
    state = state.copyWith(timers: newTimers);
    _deleteTimerFromHive(id);
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
    
    _saveTimerToHive(updatedTimer);
  }

  /// 调整运行中的倒计时剩余时间
  /// [adjustSeconds] 正数延长时间，负数加速（减少时间）
  /// 注意：只调整当前这一轮的剩余时间，不修改设定的总时长
  void adjustTime(String id, int adjustSeconds) {
    final index = state.timers.indexWhere((t) => t.id == id);
    if (index == -1) return;

    final timer = state.timers[index];
    // 只有运行中才能调整时间
    if (timer.status != CountdownTimerStatus.running) return;

    // 只调整剩余时间，不修改totalSeconds
    final newRemaining = (timer.remainingSeconds + adjustSeconds).clamp(0, timer.totalSeconds + 1800);
    
    final now = DateTime.now();
    CountdownTimerModel updatedTimer;
    
    if (newRemaining <= 0) {
      // 如果调整后时间归零，标记为完成
      updatedTimer = timer.copyWith(
        status: CountdownTimerStatus.completed,
        remainingSeconds: 0,
        lastUpdateTime: now,
      );
      LatheNotificationService.instance.showTimerCompletedNotification(timer.name);
    } else {
      updatedTimer = timer.copyWith(
        remainingSeconds: newRemaining,
        lastUpdateTime: now,
      );
    }

    final newTimers = List<CountdownTimerModel>.from(state.timers);
    newTimers[index] = updatedTimer;
    state = state.copyWith(timers: newTimers);
    
    _saveTimerToHive(updatedTimer);
  }

  /// 快速加速（减少10秒）
  void speedUp(String id) => adjustTime(id, -10);

  /// 快速延长（增加10秒）
  void extendTime(String id) => adjustTime(id, 10);

  /// 开始倒计时
  void startTimer(String id) {
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
    
    _saveTimerToHive(updatedTimer);
    _startTickTimer();
  }

  /// 停止倒计时（恢复到未开启状态）
  void stopTimer(String id) {
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
    
    _saveTimerToHive(updatedTimer);
  }

  /// 重新开始倒计时（从完成状态开始新一轮）
  void restartTimer(String id) {
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
    
    _saveTimerToHive(updatedTimer);
    _startTickTimer();
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
    
    // 定期保存到Hive（每次tick都保存以保证数据不丢失）
    _saveAllToHive();

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
    }
  }

  /// 页面恢复时同步状态（处理后台恢复）
  void syncOnResume() {
    if (!state.hasRunningTimers) return;
    _onTick(); // 立即执行一次tick以同步时间
    _startTickTimer(); // 确保计时器在运行
  }
}
