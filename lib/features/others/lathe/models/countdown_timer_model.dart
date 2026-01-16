import 'package:flutter/foundation.dart';

/// 倒计时器状态枚举
enum CountdownTimerStatus {
  /// 空闲状态，未开始
  idle,
  /// 运行中
  running,
  /// 已完成（归零），等待重新开始
  completed,
}

/// 倒计时器数据模型
@immutable
class CountdownTimerModel {
  /// 唯一标识符
  final String id;
  
  /// 倒计时名称
  final String name;
  
  /// 设定的总时长（秒），最大3600秒（60分钟）
  final int totalSeconds;
  
  /// 剩余时间（秒）
  final int remainingSeconds;
  
  /// 当前状态
  final CountdownTimerStatus status;
  
  /// 上次更新时间戳（用于计算息屏后的实际时间）
  final DateTime? lastUpdateTime;
  
  /// 开始时间戳
  final DateTime? startTime;

  const CountdownTimerModel({
    required this.id,
    required this.name,
    required this.totalSeconds,
    required this.remainingSeconds,
    this.status = CountdownTimerStatus.idle,
    this.lastUpdateTime,
    this.startTime,
  });

  /// 已过时间百分比 (0.0 - 1.0)
  double get progressPercentage {
    if (totalSeconds == 0) return 0.0;
    final elapsed = totalSeconds - remainingSeconds;
    return (elapsed / totalSeconds).clamp(0.0, 1.0);
  }

  /// 格式化剩余时间显示 (mm:ss)
  String get formattedRemainingTime {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// 格式化总时间显示 (mm:ss)
  String get formattedTotalTime {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// 是否正在运行
  bool get isRunning => status == CountdownTimerStatus.running;

  /// 是否已完成
  bool get isCompleted => status == CountdownTimerStatus.completed;

  /// 是否空闲
  bool get isIdle => status == CountdownTimerStatus.idle;

  CountdownTimerModel copyWith({
    String? id,
    String? name,
    int? totalSeconds,
    int? remainingSeconds,
    CountdownTimerStatus? status,
    DateTime? lastUpdateTime,
    DateTime? startTime,
  }) {
    return CountdownTimerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      status: status ?? this.status,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
      startTime: startTime ?? this.startTime,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CountdownTimerModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          totalSeconds == other.totalSeconds &&
          remainingSeconds == other.remainingSeconds &&
          status == other.status;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      totalSeconds.hashCode ^
      remainingSeconds.hashCode ^
      status.hashCode;

  @override
  String toString() {
    return 'CountdownTimerModel(id: $id, name: $name, total: $totalSeconds, remaining: $remainingSeconds, status: $status)';
  }
}
