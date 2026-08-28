import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:northstar/application/comix/providers/comix_providers.dart';
import 'package:northstar/app/theme.dart';
import 'package:northstar/domain/comix/models/comix_models.dart';
import 'package:northstar/ui/comix/widgets/comix_widgets.dart';

/// 任务面板 Tab：Go 端任务引擎管理的爬虫任务（状态/日志/中断）。
class TasksTab extends ConsumerWidget {
  const TasksTab({super.key});

  Future<void> _stop(WidgetRef ref, BuildContext context, String taskId) async {
    try {
      await ref.read(comixBoardProvider.notifier).stopTask(taskId);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('已发送中断指令：$taskId')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('中断失败: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(comixBoardProvider);
    final tasks = board.tasks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.paddingL,
            AppDimens.paddingM,
            AppDimens.paddingL,
            0,
          ),
          child: Row(
            children: [
              Text('任务面板', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: 8),
              if (board.refreshing)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              const Spacer(),
              Text(
                '${tasks.where((t) => t.isRunning).length} 运行中 / ${tasks.length} 总',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (board.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.paddingL),
            child: Text(
              '任务刷新失败: ${board.error}',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: AppDimens.spacingS),
        Expanded(
          child: tasks.isEmpty
              ? const Center(child: Text('暂无任务'))
              : ListView.separated(
                  padding: const EdgeInsets.all(AppDimens.paddingL),
                  itemCount: tasks.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppDimens.spacingS),
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return _TaskTile(
                      task: task,
                      onStop: () => _stop(ref, context, task.id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _TaskTile extends StatefulWidget {
  final ComixTask task;
  final VoidCallback onStop;

  const _TaskTile({required this.task, required this.onStop});

  @override
  State<_TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<_TaskTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.paddingM,
          vertical: AppDimens.paddingS,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TaskStatusChip(status: task.status),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${task.name} (${task.id})',
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (task.isRunning)
                  IconButton(
                    tooltip: '中断',
                    onPressed: widget.onStop,
                    icon: Icon(
                      Icons.stop_circle_outlined,
                      color: Theme.of(context).colorScheme.error,
                      size: 20,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                IconButton(
                  tooltip: _expanded ? '收起' : '展开日志',
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            Text(
              task.command,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (task.error != null && task.error!.isNotEmpty)
              Text(
                task.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (task.result != null)
              Text(
                comixTaskSummary(task),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (task.pid > 0)
              Text(
                'PID ${task.pid} · 开始 ${task.startedAt ?? '-'}'
                '${task.finishedAt != null ? ' · 结束 ${task.finishedAt}' : ''}'
                '${task.exitCode != null ? ' · exit ${task.exitCode}' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (_expanded && task.logs.isNotEmpty) ...[
              const Divider(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 260),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppDimens.smallBorderRadius),
                ),
                padding: const EdgeInsets.all(AppDimens.paddingS),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final log in task.logs)
                        SelectableText(
                          '[${log.stream}] ${log.text}',
                          style: comixLogTextStyle,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
