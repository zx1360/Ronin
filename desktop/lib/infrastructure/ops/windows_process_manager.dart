import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:northstar/domain/ops/models/arg_preset.dart';
import 'package:northstar/domain/ops/models/process_log_entry.dart';
import 'package:northstar/domain/ops/models/task_profile.dart';

typedef ProcessLogCallback = void Function(ProcessLogEntry entry);
typedef ProcessExitCallback = void Function(int? exitCode);

class ProcessStartResult {
  final bool ok;
  final int? pid;
  final String? error;

  const ProcessStartResult._({required this.ok, this.pid, this.error});

  factory ProcessStartResult.success(int pid) {
    return ProcessStartResult._(ok: true, pid: pid);
  }

  factory ProcessStartResult.failure(String error) {
    return ProcessStartResult._(ok: false, error: error);
  }
}

class WindowsProcessManager {
  final Map<String, _RunningProcess> _running = <String, _RunningProcess>{};

  bool isRunning(String taskId) => _running.containsKey(taskId);

  bool get hasRunningProcess => _running.isNotEmpty;

  List<int> get runningPids =>
      _running.values.map((item) => item.process.pid).toList(growable: false);

  Future<ProcessStartResult> start({
    required TaskProfile task,
    required ArgPreset preset,
    required ProcessLogCallback onLog,
    required ProcessExitCallback onExit,
  }) async {
    if (isRunning(task.id)) {
      return ProcessStartResult.failure('任务已在运行中');
    }

    final executablePath = task.executablePath.trim();
    if (executablePath.isEmpty) {
      return ProcessStartResult.failure('请先配置可执行文件路径');
    }

    final executableExists = await File(executablePath).exists();
    if (!executableExists) {
      return ProcessStartResult.failure('可执行文件不存在: $executablePath');
    }

    final workingDirectory = task.workingDirectory.trim();
    if (workingDirectory.isNotEmpty) {
      final directoryExists = await Directory(workingDirectory).exists();
      if (!directoryExists) {
        return ProcessStartResult.failure('工作目录不存在: $workingDirectory');
      }
    }

    Process process;
    try {
      if (workingDirectory.isEmpty) {
        process = await Process.start(
          executablePath,
          preset.args,
          runInShell: false,
        );
      } else {
        process = await Process.start(
          executablePath,
          preset.args,
          runInShell: false,
          workingDirectory: workingDirectory,
        );
      }
    } catch (error) {
      return ProcessStartResult.failure('启动失败: $error');
    }

    final running = _RunningProcess(process: process);
    _running[task.id] = running;

    onLog(
      ProcessLogEntry(
        taskId: task.id,
        time: DateTime.now(),
        streamType: LogStreamType.system,
        text: workingDirectory.isEmpty
            ? '进程已启动, PID=${process.pid}, CWD=(默认)'
            : '进程已启动, PID=${process.pid}, CWD=$workingDirectory',
      ),
    );

    running.stdoutSub = utf8.decoder
        .bind(process.stdout)
        .transform(const LineSplitter())
        .listen((line) {
          onLog(
            ProcessLogEntry(
              taskId: task.id,
              time: DateTime.now(),
              streamType: LogStreamType.stdout,
              text: line,
            ),
          );
        });

    running.stderrSub = utf8.decoder
        .bind(process.stderr)
        .transform(const LineSplitter())
        .listen((line) {
          onLog(
            ProcessLogEntry(
              taskId: task.id,
              time: DateTime.now(),
              streamType: LogStreamType.stderr,
              text: line,
            ),
          );
        });

    running.exitCodeFuture = process.exitCode.then((exitCode) async {
      await _remove(task.id);
      onLog(
        ProcessLogEntry(
          taskId: task.id,
          time: DateTime.now(),
          streamType: LogStreamType.system,
          text: '进程已退出, exitCode=$exitCode',
        ),
      );
      onExit(exitCode);
      return exitCode;
    });

    return ProcessStartResult.success(process.pid);
  }

  Future<void> stop({
    required String taskId,
    required bool supportsGracefulStop,
    Duration gracefulTimeout = const Duration(seconds: 3),
  }) async {
    final running = _running[taskId];
    if (running == null) {
      return;
    }

    if (supportsGracefulStop) {
      running.process.kill(ProcessSignal.sigterm);
      final exited = await _waitForExit(running, gracefulTimeout);
      if (exited) {
        return;
      }
    }

    await Process.run('taskkill', <String>[
      '/PID',
      '${running.process.pid}',
      '/T',
      '/F',
    ]);

    await _waitForExit(running, const Duration(seconds: 2));
  }

  Future<void> terminateAll() async {
    final taskIds = _running.keys.toList(growable: false);
    for (final taskId in taskIds) {
      final running = _running[taskId];
      if (running == null) {
        continue;
      }
      await stop(taskId: taskId, supportsGracefulStop: false);
    }
  }

  Future<bool> _waitForExit(_RunningProcess running, Duration timeout) async {
    final exitFuture = running.exitCodeFuture;
    if (exitFuture == null) {
      return false;
    }

    try {
      await exitFuture.timeout(timeout);
      return true;
    } on TimeoutException {
      return false;
    }
  }

  Future<void> _remove(String taskId) async {
    final running = _running.remove(taskId);
    if (running == null) {
      return;
    }

    await running.stdoutSub?.cancel();
    await running.stderrSub?.cancel();
  }
}

class _RunningProcess {
  final Process process;
  StreamSubscription<String>? stdoutSub;
  StreamSubscription<String>? stderrSub;
  Future<int>? exitCodeFuture;

  _RunningProcess({required this.process});
}
