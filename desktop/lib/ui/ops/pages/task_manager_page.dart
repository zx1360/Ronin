import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:northstar/application/ops/providers/runtime_process_provider.dart';
import 'package:northstar/application/ops/providers/task_profiles_provider.dart';
import 'package:northstar/app/theme.dart';
import 'package:northstar/domain/ops/models/runtime_process_state.dart';
import 'package:northstar/domain/ops/models/task_profile.dart';
import 'package:northstar/domain/ops/utils/task_rules.dart';
import 'package:northstar/shared/widgets/heading/heading.dart';
import 'package:northstar/ui/ops/widgets/danger_confirm_dialog.dart';
import 'package:northstar/ui/ops/widgets/runtime_status_badge.dart';
import 'package:northstar/ui/ops/widgets/task_editor_dialog.dart';

class TaskManagerPage extends ConsumerStatefulWidget {
  const TaskManagerPage({super.key});

  @override
  ConsumerState<TaskManagerPage> createState() => _TaskManagerPageState();
}

class _TaskManagerPageState extends ConsumerState<TaskManagerPage> {
  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(taskProfilesControllerProvider);

    final visibleTasks = tasks
        .where((task) => !task.hiddenByDefault)
        .toList(growable: false);
    final hiddenTasks = tasks
        .where((task) => task.hiddenByDefault)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Heading(title: '任务管理'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimens.paddingL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _addTask,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('新增任务'),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '共 ${tasks.length} 个任务',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.spacingL),
                for (final task in visibleTasks) ...[
                  _TaskCard(task: task),
                  const SizedBox(height: AppDimens.spacingM),
                ],
                if (hiddenTasks.isNotEmpty)
                  ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                    title: Text('隐藏任务 (${hiddenTasks.length})'),
                    childrenPadding: const EdgeInsets.only(top: 8),
                    children: [
                      for (final task in hiddenTasks) ...[
                        _TaskCard(task: task),
                        const SizedBox(height: AppDimens.spacingM),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _addTask() async {
    final result = await showDialog<TaskProfile>(
      context: context,
      builder: (_) => const TaskEditorDialog(),
    );

    if (result == null || !mounted) {
      return;
    }

    await ref.read(taskProfilesControllerProvider.notifier).upsertTask(result);
  }
}

class _TaskCard extends ConsumerWidget {
  final TaskProfile task;

  const _TaskCard({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runtimeBoard = ref.watch(runtimeProcessControllerProvider);
    final runtimeController = ref.read(
      runtimeProcessControllerProvider.notifier,
    );
    final taskController = ref.read(taskProfilesControllerProvider.notifier);

    final runtime =
        runtimeBoard.runtimes[task.id] ?? RuntimeProcessState.idle(task.id);
    final preset = task.selectedPreset;
    final exeExists =
        task.executablePath.isNotEmpty &&
        File(task.executablePath).existsSync();
    final configuredWorkingDirectory = task.workingDirectory.trim();
    final hasConfiguredWorkingDirectory = configuredWorkingDirectory.isNotEmpty;
    final workingDirectoryValid =
        hasConfiguredWorkingDirectory &&
        _directoryExists(configuredWorkingDirectory);

    final isRunning =
        runtime.status == RuntimeStatus.running ||
        runtime.status == RuntimeStatus.starting ||
        runtime.status == RuntimeStatus.stopping;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                RuntimeStatusBadge(status: runtime.status),
                const SizedBox(width: 8),
                Text('PID: ${runtime.pid?.toString() ?? '-'}'),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PathChip(
                  ok: exeExists,
                  label: exeExists ? 'exe路径有效' : 'exe路径无效',
                ),
                _PathChip(
                  ok: !hasConfiguredWorkingDirectory || workingDirectoryValid,
                  label: hasConfiguredWorkingDirectory
                      ? (workingDirectoryValid ? '工作目录有效' : '工作目录无效')
                      : '工作目录: 默认',
                ),
                if (task.dangerousOperation)
                  const _PathChip(ok: false, label: '危险任务'),
                if (task.supportsGracefulStop)
                  const _PathChip(ok: true, label: '支持温和中断'),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: task.selectedPreset.id,
              decoration: const InputDecoration(labelText: '参数预设'),
              items: task.presets
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item.id,
                      child: Text(item.name),
                    ),
                  )
                  .toList(growable: false),
              onChanged: isRunning
                  ? null
                  : (value) async {
                      if (value == null) {
                        return;
                      }
                      await taskController.setSelectedPreset(
                        taskId: task.id,
                        presetId: value,
                      );
                    },
            ),
            const SizedBox(height: 8),
            SelectableText('当前参数字符串: ${preset.argsText}'),
            const SizedBox(height: 4),
            SelectableText(
              hasConfiguredWorkingDirectory
                  ? '启动工作目录: $configuredWorkingDirectory (手动)'
                  : '启动工作目录: (默认)',
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: isRunning
                      ? null
                      : () async {
                          var canRun = true;
                          if (requiresDangerConfirmation(task, preset)) {
                            final phrase = buildDangerPhrase(task, preset);
                            canRun = await showDangerConfirmDialog(
                              context: context,
                              phrase: phrase,
                              title: '危险任务确认',
                            );
                          }

                          if (!canRun || !context.mounted) {
                            return;
                          }

                          final result = await runtimeController.startTask(
                            task,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  result.message ??
                                      (result.ok ? '已启动' : '启动失败'),
                                ),
                              ),
                            );
                          }
                        },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('启动'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: isRunning
                      ? () async {
                          final result = await runtimeController.stopTask(task);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(result.message ?? '已发送停止命令'),
                              ),
                            );
                          }
                        }
                      : null,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('中断'),
                ),
                const Spacer(),
                IconButton(
                  tooltip: '编辑任务',
                  onPressed: isRunning
                      ? null
                      : () async {
                          final result = await showDialog<TaskProfile>(
                            context: context,
                            builder: (_) => TaskEditorDialog(initial: task),
                          );
                          if (result == null) {
                            return;
                          }
                          await taskController.upsertTask(result);
                        },
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: '删除任务',
                  onPressed: isRunning
                      ? null
                      : () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('删除任务'),
                              content: Text('确认删除任务 ${task.name} 吗？'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: const Text('取消'),
                                ),
                                ElevatedButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  child: const Text('删除'),
                                ),
                              ],
                            ),
                          );

                          if (confirmed == true) {
                            await taskController.removeTask(task.id);
                          }
                        },
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            if ((runtime.message ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(runtime.message ?? ''),
              ),
          ],
        ),
      ),
    );
  }

  bool _directoryExists(String path) {
    try {
      return Directory(path).existsSync();
    } catch (_) {
      return false;
    }
  }
}

class _PathChip extends StatelessWidget {
  final bool ok;
  final String label;

  const _PathChip({required this.ok, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = ok
        ? Colors.greenAccent.shade400
        : Theme.of(context).colorScheme.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
      ),
    );
  }
}
