enum RuntimeStatus {
  idle,
  starting,
  running,
  stopping,
  stopped,
  failed,
}

class RuntimeProcessState {
  final String taskId;
  final RuntimeStatus status;
  final int? pid;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int? exitCode;
  final String? message;

  const RuntimeProcessState({
    required this.taskId,
    required this.status,
    this.pid,
    this.startedAt,
    this.endedAt,
    this.exitCode,
    this.message,
  });

  bool get isRunning => status == RuntimeStatus.running;

  RuntimeProcessState copyWith({
    String? taskId,
    RuntimeStatus? status,
    int? pid,
    DateTime? startedAt,
    DateTime? endedAt,
    int? exitCode,
    String? message,
    bool clearPid = false,
    bool clearMessage = false,
  }) {
    return RuntimeProcessState(
      taskId: taskId ?? this.taskId,
      status: status ?? this.status,
      pid: clearPid ? null : (pid ?? this.pid),
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      exitCode: exitCode ?? this.exitCode,
      message: clearMessage ? null : (message ?? this.message),
    );
  }

  factory RuntimeProcessState.idle(String taskId) {
    return RuntimeProcessState(taskId: taskId, status: RuntimeStatus.idle);
  }
}
