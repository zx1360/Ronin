import 'dart:async';

import 'package:northstar/application/ops/providers/core_services_provider.dart';
import 'package:northstar/domain/ops/models/process_log_entry.dart';
import 'package:northstar/domain/ops/models/runtime_process_state.dart';
import 'package:northstar/domain/ops/models/task_profile.dart';
import 'package:northstar/domain/ops/utils/task_rules.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'runtime_process_provider.g.dart';

class RuntimeBoardState {
  final Map<String, RuntimeProcessState> runtimes;
  final Map<String, List<ProcessLogEntry>> logs;
  final int maxLinesPerTask;

  const RuntimeBoardState({
    required this.runtimes,
    required this.logs,
    required this.maxLinesPerTask,
  });

  factory RuntimeBoardState.initial() {
    return const RuntimeBoardState(
      runtimes: <String, RuntimeProcessState>{},
      logs: <String, List<ProcessLogEntry>>{},
      maxLinesPerTask: 1200,
    );
  }

  RuntimeBoardState copyWith({
    Map<String, RuntimeProcessState>? runtimes,
    Map<String, List<ProcessLogEntry>>? logs,
    int? maxLinesPerTask,
  }) {
    return RuntimeBoardState(
      runtimes: runtimes ?? this.runtimes,
      logs: logs ?? this.logs,
      maxLinesPerTask: maxLinesPerTask ?? this.maxLinesPerTask,
    );
  }
}

class RuntimeActionResult {
  final bool ok;
  final String? message;

  const RuntimeActionResult({required this.ok, this.message});

  factory RuntimeActionResult.success([String? message]) {
    return RuntimeActionResult(ok: true, message: message);
  }

  factory RuntimeActionResult.failure(String message) {
    return RuntimeActionResult(ok: false, message: message);
  }
}

@Riverpod(keepAlive: true)
class RuntimeProcessController extends _$RuntimeProcessController {
  @override
  RuntimeBoardState build() {
    return RuntimeBoardState.initial();
  }

  RuntimeProcessState runtimeOf(String taskId) {
    return state.runtimes[taskId] ?? RuntimeProcessState.idle(taskId);
  }

  List<ProcessLogEntry> logsOf(String taskId) {
    return state.logs[taskId] ?? const <ProcessLogEntry>[];
  }

  bool get hasRunningTasks {
    for (final runtime in state.runtimes.values) {
      if (runtime.status == RuntimeStatus.running ||
          runtime.status == RuntimeStatus.starting ||
          runtime.status == RuntimeStatus.stopping) {
        return true;
      }
    }
    return false;
  }

  Future<RuntimeActionResult> startTask(TaskProfile task) async {
    final manager = ref.read(windowsProcessManagerProvider);
    final checker = ref.read(dependencyCheckerProvider);
    final preset = task.selectedPreset;

    if (manager.isRunning(task.id)) {
      return RuntimeActionResult.failure('任务已在运行中');
    }

    if (requiresFfmpegCheck(task, preset)) {
      final missing = await checker.findMissingCommands(
        const <String>['ffmpeg', 'ffprobe'],
      );
      if (missing.isNotEmpty) {
        return RuntimeActionResult.failure(
          '缺失依赖: ${missing.join(', ')}，请先安装并加入 PATH',
        );
      }
    }

    _updateRuntime(
      task.id,
      RuntimeProcessState(
        taskId: task.id,
        status: RuntimeStatus.starting,
        startedAt: DateTime.now(),
      ),
    );

    final result = await manager.start(
      task: task,
      preset: preset,
      onLog: _appendLog,
      onExit: (exitCode) {
        final status = (exitCode ?? 1) == 0
            ? RuntimeStatus.stopped
            : RuntimeStatus.failed;
        _updateRuntime(
          task.id,
          RuntimeProcessState(
            taskId: task.id,
            status: status,
            pid: runtimeOf(task.id).pid,
            startedAt: runtimeOf(task.id).startedAt,
            endedAt: DateTime.now(),
            exitCode: exitCode,
            message: exitCode == 0 ? '任务已结束' : '进程异常退出',
          ),
        );
      },
    );

    if (!result.ok || result.pid == null) {
      _updateRuntime(
        task.id,
        RuntimeProcessState(
          taskId: task.id,
          status: RuntimeStatus.failed,
          startedAt: runtimeOf(task.id).startedAt,
          endedAt: DateTime.now(),
          message: result.error ?? '启动失败',
        ),
      );
      return RuntimeActionResult.failure(result.error ?? '启动失败');
    }

    _updateRuntime(
      task.id,
      RuntimeProcessState(
        taskId: task.id,
        status: RuntimeStatus.running,
        pid: result.pid,
        startedAt: runtimeOf(task.id).startedAt ?? DateTime.now(),
        message: '运行中',
      ),
    );

    return RuntimeActionResult.success('任务已启动');
  }

  Future<RuntimeActionResult> stopTask(TaskProfile task) async {
    final manager = ref.read(windowsProcessManagerProvider);
    if (!manager.isRunning(task.id)) {
      return RuntimeActionResult.failure('任务未运行');
    }

    _updateRuntime(
      task.id,
      runtimeOf(task.id).copyWith(
        status: RuntimeStatus.stopping,
        message: '正在停止...',
      ),
    );

    try {
      await manager.stop(
        taskId: task.id,
        supportsGracefulStop: task.supportsGracefulStop,
      );
      return RuntimeActionResult.success('已发送停止命令');
    } catch (error) {
      _appendLog(
        ProcessLogEntry(
          taskId: task.id,
          time: DateTime.now(),
          streamType: LogStreamType.system,
          text: '停止失败: $error',
        ),
      );
      _updateRuntime(
        task.id,
        runtimeOf(task.id).copyWith(
          status: RuntimeStatus.failed,
          message: '停止失败: $error',
        ),
      );
      return RuntimeActionResult.failure('停止失败: $error');
    }
  }

  void clearLogs(String taskId) {
    final nextLogs = Map<String, List<ProcessLogEntry>>.from(state.logs);
    nextLogs[taskId] = const <ProcessLogEntry>[];
    state = state.copyWith(logs: nextLogs);
  }

  Future<void> terminateAllRunningProcesses() async {
    final manager = ref.read(windowsProcessManagerProvider);
    await manager.terminateAll();
  }

  void _appendLog(ProcessLogEntry entry) {
    final nextLogs = Map<String, List<ProcessLogEntry>>.from(state.logs);
    final list = List<ProcessLogEntry>.from(nextLogs[entry.taskId] ?? const <ProcessLogEntry>[])
      ..add(entry);

    if (list.length > state.maxLinesPerTask) {
      list.removeRange(0, list.length - state.maxLinesPerTask);
    }

    nextLogs[entry.taskId] = list;
    state = state.copyWith(logs: nextLogs);
  }

  void _updateRuntime(String taskId, RuntimeProcessState runtime) {
    final next = Map<String, RuntimeProcessState>.from(state.runtimes);
    next[taskId] = runtime;
    state = state.copyWith(runtimes: next);
  }
}
