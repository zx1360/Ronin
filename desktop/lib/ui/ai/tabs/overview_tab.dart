import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:northstar/app/theme.dart';
import 'package:northstar/core/providers/ai/ai_providers.dart';
import 'package:northstar/core/providers/ops/ops_settings_provider.dart';
import 'package:northstar/domain/ai/models/ai_models.dart';
import 'package:northstar/ui/ai/widgets/ai_widgets.dart';

/// AI 概览：能力就绪状态、处理进度、模型进程启停、自动处理开关。
class AiOverviewTab extends ConsumerWidget {
  const AiOverviewTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(aiBoardProvider);
    final status = board.status;
    final notifier = ref.read(aiBoardProvider.notifier);

    if (status == null) {
      return Center(
        child: board.error != null
            ? Text(
                board.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            : const CircularProgressIndicator(),
      );
    }

    if (!status.schemaReady) {
      return _MissingSchemaHint(error: board.error);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimens.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderRow(status: status, board: board),
          if (board.error != null || board.notice != null) ...[
            const SizedBox(height: AppDimens.spacingS),
            _MessageCard(
              text: board.error ?? board.notice!,
              isError: board.error != null,
            ),
          ],
          if (status.lastRun != null) ...[
            const SizedBox(height: AppDimens.spacingM),
            _LastRunCard(run: status.lastRun!),
          ],
          const SizedBox(height: AppDimens.spacingM),
          Text('处理能力', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppDimens.spacingS),
          for (final capability in status.capabilities) ...[
            _CapabilityCard(
              capability: capability,
              busy: board.busy,
              onAction: notifier.run,
            ),
            const SizedBox(height: AppDimens.spacingS),
          ],
          const SizedBox(height: AppDimens.spacingS),
          _RuntimeCard(status: status),
          const SizedBox(height: AppDimens.spacingM),
          _AutoCapabilityCard(status: status, notifier: notifier),
        ],
      ),
    );
  }
}

class _MissingSchemaHint extends StatelessWidget {
  final String? error;

  const _MissingSchemaHint({this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.paddingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storage_rounded, size: 40),
            const SizedBox(height: AppDimens.spacingM),
            const Text('AI 处理层尚未初始化'),
            const SizedBox(height: AppDimens.spacingS),
            Text(
              '请在 PostgreSQL 中执行 backend/references/db/ai.sql 后重启 Monarch。\n'
              '该脚本只新增 ai schema，不影响 gallery / user_data 的既有数据。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (error != null) ...[
              const SizedBox(height: AppDimens.spacingS),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeaderRow extends ConsumerWidget {
  final AiStatus status;
  final AiBoardState board;

  const _HeaderRow({required this.status, required this.board});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(aiBoardProvider.notifier);
    final online = status.started;
    return Row(
      children: [
        AiStatusPill(
          text: status.enabled
              ? (online ? 'AI 处理层运行中' : '已启用但未启动')
              : '已通过 AI_ENABLED=false 关闭',
          color: status.enabled && online
              ? AppColors.success
              : Theme.of(context).colorScheme.error,
        ),
        const SizedBox(width: 8),
        AiStatusPill(
          text: '待处理 ${status.pendingTotal}',
          color: status.pendingTotal > 0 ? AppColors.info : AppColors.outline,
        ),
        const SizedBox(width: 8),
        AiStatusPill(
          text: '失败 ${status.failedTotal}',
          color: status.failedTotal > 0
              ? Theme.of(context).colorScheme.error
              : AppColors.outline,
        ),
        if (status.paused) ...[
          const SizedBox(width: 8),
          const AiStatusPill(text: '已暂停', color: AppColors.warning),
        ],
        const Spacer(),
        OutlinedButton.icon(
          onPressed: board.busy
              ? null
              : () => notifier.run(
                    status.paused ? '已继续处理' : '已暂停处理队列',
                    () async {
                      final client = ref.read(aiApiClientProvider);
                      final settings = ref.read(opsSettingsControllerProvider);
                      if (status.paused) {
                        await client.resume(settings);
                      } else {
                        await client.pause(settings);
                      }
                    },
                  ),
          icon: Icon(
            status.paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            size: 16,
          ),
          label: Text(status.paused ? '继续处理' : '暂停处理'),
          style: _compactButton,
        ),
        const SizedBox(width: AppDimens.spacingS),
        OutlinedButton.icon(
          onPressed: board.loading ? null : () => notifier.refresh(),
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('刷新'),
          style: _compactButton,
        ),
      ],
    );
  }
}

final _compactButton = OutlinedButton.styleFrom(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  visualDensity: VisualDensity.compact,
);

class _MessageCard extends StatelessWidget {
  final String text;
  final bool isError;

  const _MessageCard({required this.text, required this.isError});

  @override
  Widget build(BuildContext context) {
    final color =
        isError ? Theme.of(context).colorScheme.error : AppColors.success;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.paddingS),
        child: Text(text, style: TextStyle(color: color, fontSize: 12)),
      ),
    );
  }
}

class _LastRunCard extends StatelessWidget {
  final AiRunInfo run;

  const _LastRunCard({required this.run});

  @override
  Widget build(BuildContext context) {
    final meta = AiCapabilityMeta.of(run.capability);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(meta.icon, size: 16),
                const SizedBox(width: 6),
                Text('当前批次：${meta.label}'),
                const SizedBox(width: 8),
                AiStatusPill(
                  text: run.running ? '执行中' : '已结束',
                  color: run.running ? AppColors.info : AppColors.outline,
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spacingS),
            AiProgressBar(
              done: run.processed,
              pending: run.total - run.processed,
              label: '本批进度（失败 ${run.failed}）',
            ),
          ],
        ),
      ),
    );
  }
}

/// 单个能力的卡片：状态、进度、入队与进程控制。
class _CapabilityCard extends ConsumerWidget {
  final AiCapabilityStatus capability;
  final bool busy;
  final Future<bool> Function(String notice, Future<void> Function() action)
      onAction;

  const _CapabilityCard({
    required this.capability,
    required this.busy,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = AiCapabilityMeta.of(capability.capability);
    final sidecar = capability.sidecar;
    final running = sidecar?.running ?? false;
    final client = ref.read(aiApiClientProvider);
    final settings = ref.read(opsSettingsControllerProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(meta.icon, size: 16),
                const SizedBox(width: 6),
                Text(meta.label,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(width: 8),
                AiStatusPill(
                  text: capability.ready ? '就绪' : '未就绪',
                  color: capability.ready
                      ? AppColors.success
                      : Theme.of(context).colorScheme.error,
                ),
                if (running) ...[
                  const SizedBox(width: 6),
                  AiStatusPill(
                    text: '进程运行中 PID ${sidecar!.pid}',
                    color: AppColors.info,
                  ),
                ],
                const Spacer(),
                if (capability.capability != 'phash' &&
                    capability.capability != 'vlm')
                  _SmallButton(
                    icon: running ? Icons.memory : Icons.play_arrow_rounded,
                    label: running ? '释放模型' : '启动模型',
                    enabled: !busy,
                    onPressed: () => onAction(
                      running ? '已释放模型进程' : '模型已就绪',
                      () => running
                          ? client.stopModel(settings, capability.capability)
                          : client.startModel(settings, capability.capability),
                    ),
                  ),
                if (capability.capability == 'vlm')
                  _SmallButton(
                    icon: Icons.power_settings_new_rounded,
                    label: '卸载模型',
                    enabled: !busy,
                    onPressed: () => onAction(
                      '已请求卸载 VLM 模型',
                      () => client.stopModel(settings, 'vlm'),
                    ),
                  ),
                const SizedBox(width: 6),
                _SmallButton(
                  icon: Icons.playlist_add_rounded,
                  label: '补处理 ${capability.missingMedia}',
                  enabled: !busy && capability.missingMedia > 0,
                  onPressed: () => _enqueueMissing(context, ref),
                ),
                const SizedBox(width: 6),
                _SmallButton(
                  icon: Icons.replay_rounded,
                  label: '重试 ${capability.failed}',
                  enabled: !busy && capability.failed > 0,
                  onPressed: () => onAction(
                    '已重试 ${capability.failed} 条失败任务',
                    () async => client.retry(settings,
                        capability: capability.capability),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(meta.description,
                style: Theme.of(context).textTheme.bodySmall),
            if (!capability.ready && (capability.reason ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                capability.reason!,
                style: TextStyle(color: AppColors.warning, fontSize: 12),
              ),
            ],
            const SizedBox(height: AppDimens.spacingS),
            AiProgressBar(
              done: capability.done,
              pending: capability.pending + capability.missingMedia,
              label: '已处理 / 总量',
            ),
            const SizedBox(height: 2),
            Text(
              '排队 ${capability.pending} · 失败 ${capability.failed}'
              '${sidecar != null && sidecar.idleSeconds > 0 ? ' · 空闲 ${sidecar.idleSeconds}s（${sidecar.idleTimeoutSeconds}s 后自动退出）' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  /// 补处理：把"尚无该能力产物"的媒体全部入队。
  Future<void> _enqueueMissing(BuildContext context, WidgetRef ref) async {
    // VLM 单张耗时以秒计，全库补处理代价极高，必须二次确认
    if (capability.capability == 'vlm') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('确认全库 VLM 标注？'),
          content: Text(
            '待处理 ${capability.missingMedia} 张，按每张 5-15 秒估算需要数小时至数天。\n'
            '建议先选一小批试用，确认效果后再全量跑。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('仍然提交'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    final client = ref.read(aiApiClientProvider);
    final settings = ref.read(opsSettingsControllerProvider);
    await onAction(
      '已提交 ${capability.missingMedia} 条待处理任务',
      () => client.enqueue(
        settings,
        capabilities: [capability.capability],
        scope: 'missing',
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  const _SmallButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon, size: 14),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        visualDensity: VisualDensity.compact,
        textStyle: const TextStyle(fontSize: 12),
      ),
    );
  }
}

class _RuntimeCard extends ConsumerWidget {
  final AiStatus status;

  const _RuntimeCard({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(aiBoardProvider.notifier);
    final client = ref.read(aiApiClientProvider);
    final settings = ref.read(opsSettingsControllerProvider);
    final index = status.index;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('运行时', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                _SmallButton(
                  icon: Icons.refresh_rounded,
                  label: '重建向量索引',
                  enabled: true,
                  onPressed: () => notifier.run(
                    '向量索引已重建',
                    () async => client.rebuildIndex(settings),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spacingS),
            AiInfoRow(label: '向量模型', value: index.model),
            AiInfoRow(
              label: '向量索引',
              value: '${index.vectors} 条'
                  '${index.loaded ? '（已载入内存，约 ${_mib(index.memoryEstimateBytes)}）' : '（尚未载入）'}',
            ),
            AiInfoRow(
              label: '人物分组',
              value: '${status.personCount} 组'
                  '（阈值 ${status.cluster.threshold.toStringAsFixed(2)}，'
                  '至少 ${status.cluster.minGroupFaces} 张成组）',
            ),
            AiInfoRow(
              label: 'Ollama',
              value: status.ollama.reachable
                  ? (status.ollama.modelReady
                      ? '${status.ollama.model} 已安装（上下文 ${status.ollama.numCtx}，闲置 5 分钟卸载）'
                      : '${status.ollama.model} 未安装')
                  : '不可达${status.ollama.error == null ? '' : '：${status.ollama.error}'}',
              valueColor: status.ollama.modelReady ? null : AppColors.warning,
            ),
            AiInfoRow(
              label: 'worker 配置',
              value: '推理设备 ${status.device} · 并发 ${status.workers} · 批大小 ${status.batchSize} · '
                  '批次超时 ${status.jobTimeoutSeconds}s · 重试上限 ${status.maxAttempts}',
            ),
          ],
        ),
      ),
    );
  }

  String _mib(int bytes) => '${(bytes / 1024 / 1024).toStringAsFixed(0)} MiB';
}

class _AutoCapabilityCard extends ConsumerWidget {
  final AiStatus status;
  final AiBoardNotifier notifier;

  const _AutoCapabilityCard({required this.status, required this.notifier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('入库自动处理', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              '选中的能力会在媒体入库后自动排队处理；未选中的需要手动提交。'
              'VLM 标注单张耗时长，默认不自动执行。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppDimens.spacingS),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final meta in AiCapabilityMeta.all)
                  FilterChip(
                    label: Text(meta.label),
                    selected: status.autoCapabilities.contains(meta.name),
                    onSelected: (selected) {
                      final next = [...status.autoCapabilities];
                      if (selected) {
                        if (!next.contains(meta.name)) next.add(meta.name);
                      } else {
                        next.remove(meta.name);
                      }
                      notifier.run(
                        '自动处理能力已更新',
                        () => ref
                            .read(aiApiClientProvider)
                            .updateAutoCapabilities(
                              ref.read(opsSettingsControllerProvider),
                              next,
                            ),
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
