import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:northstar/app/theme.dart';
import 'package:northstar/core/providers/ai/ai_providers.dart';
import 'package:northstar/core/providers/ops/ops_settings_provider.dart';
import 'package:northstar/domain/ai/models/ai_models.dart';
import 'package:northstar/infrastructure/ai/ai_api_client.dart';
import 'package:northstar/ui/ai/widgets/ai_widgets.dart';

/// AI 概览：能力就绪状态与输入档位、处理进度、按能力重试/全量重生成、
/// 模型进程启停、运行时可调配置。
///
/// 能力名称、说明、输入档位、执行者与候选全部来自服务端 `/API/ai/status`，
/// 端上只渲染列表。
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
            _LastRunCard(run: status.lastRun!, status: status),
          ],
          const SizedBox(height: AppDimens.spacingM),
          Text('处理能力', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(
            '同一张图按能力分档取源：轻量能力用 256 预览档，人脸/文字/描述用长边 1024 的 AI 派生档'
            '（缺失时按需生成并缓存）。换模型或换档位后，旧产物会自动重排。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
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
          const SizedBox(height: AppDimens.spacingM),
          _ProcessConfigCard(status: status, notifier: notifier),
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
              '请在数据库中执行 backend/references/db/sqlite.sql 后重启 Monarch。\n'
              '该脚本只新增 ai 侧的表与列，不影响 gallery / user_data 的既有数据。',
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
  final AiStatus status;

  const _LastRunCard({required this.run, required this.status});

  @override
  Widget build(BuildContext context) {
    final label = status.capabilityOf(run.capability)?.displayLabel ??
        run.capability;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(AiCapabilityIcon.of(run.capability), size: 16),
                const SizedBox(width: 6),
                Text('当前批次：$label'),
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

/// 单个能力的卡片：档位与执行者、状态、进度、按能力重试 / 全量重生成 / 进程控制。
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
    final sidecar = capability.sidecar;
    final running = sidecar?.running ?? false;
    final client = ref.read(aiApiClientProvider);
    final settings = ref.read(opsSettingsControllerProvider);
    final name = capability.capability;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(AiCapabilityIcon.of(name), size: 16),
                const SizedBox(width: 6),
                Text(capability.displayLabel,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(width: 8),
                AiStatusPill(
                  text: capability.ready ? '就绪' : '未就绪',
                  color: capability.ready
                      ? AppColors.success
                      : Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 6),
                AiTierPill(
                  tier: capability.inputTier,
                  note: capability.tierNote,
                ),
                if (capability.staleMedia > 0) ...[
                  const SizedBox(width: 6),
                  Tooltip(
                    message: '输入档位或执行者已变更，这 ${
                        capability.staleMedia
                    } 条旧产物会自动重新处理',
                    child: AiStatusPill(
                      text: '待重排 ${capability.staleMedia}',
                      color: AppColors.warning,
                      icon: Icons.autorenew_rounded,
                    ),
                  ),
                ],
                if (running) ...[
                  const SizedBox(width: 6),
                  AiStatusPill(
                    text: '进程运行中 PID ${sidecar!.pid}',
                    color: AppColors.info,
                  ),
                ],
                const Spacer(),
                if (name != 'phash' && name != 'vlm')
                  _SmallButton(
                    icon: running ? Icons.memory : Icons.play_arrow_rounded,
                    label: running ? '释放模型' : '启动模型',
                    enabled: !busy,
                    onPressed: () => onAction(
                      running ? '已释放模型进程' : '模型已就绪',
                      () => running
                          ? client.stopModel(settings, name)
                          : client.startModel(settings, name),
                    ),
                  ),
                if (name == 'vlm')
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
                  label: '重试失败项 ${capability.failed}',
                  enabled: !busy && capability.failed > 0,
                  onPressed: () => onAction(
                    '已重试 ${capability.failed} 条失败任务',
                    () async => client.retry(settings, capability: name),
                  ),
                ),
                const SizedBox(width: 6),
                _SmallButton(
                  icon: Icons.restart_alt_rounded,
                  label: '全量重生成',
                  enabled: !busy,
                  onPressed: () => _regenerate(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(capability.description,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 2),
            Text(
              '执行者 ${capability.executor}'
              '${capability.tierNote.isEmpty ? '' : ' · ${capability.tierNote}'}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
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

  /// 全量重生成：清空该能力既有产物后全库重算，必须二次确认。
  Future<void> _regenerate(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('全量重生成「${capability.displayLabel}」？'),
        content: Text(
          '将先清空该能力的 ${capability.done} 条既有结果，再把全部媒体重新排队。\n'
          '清空期间这项能力的检索/筛选会短暂为空；其它能力的产物不受影响。\n'
          '本操作只作用于「${capability.displayLabel}」，不会连带重算其它能力。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认重生成'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final client = ref.read(aiApiClientProvider);
    final settings = ref.read(opsSettingsControllerProvider);
    await onAction(
      '已清空 ${capability.displayLabel} 的旧结果并重新排队',
      () => client.regenerate(settings, capability.capability),
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
            const SizedBox(height: AppDimens.spacingS),
            _ModelSelector(status: status, notifier: notifier, client: client),
          ],
        ),
      ),
    );
  }

  String _mib(int bytes) => '${(bytes / 1024 / 1024).toStringAsFixed(0)} MiB';
}

/// VLM 标注模型选择：候选名单由服务端下发（标准版 / 无审查版），端上不硬编码。
///
/// 本机只有一块 GPU：两端选用不同模型时，前台对话会抢占后台标注并释放显存，
/// 被中断的批次会退回队列（不计失败），下一次自动重排。
class _ModelSelector extends ConsumerWidget {
  const _ModelSelector({
    required this.status,
    required this.notifier,
    required this.client,
  });

  final AiStatus status;
  final AiBoardNotifier notifier;
  final AiApiClient client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ollama = status.ollama;
    final vlm = status.capabilityOf('vlm');
    final candidates = vlm?.executorCandidates ?? const <AiExecutorCandidate>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('VLM 标注模型', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(width: AppDimens.spacingS),
            Text(
              ollama.activeModel.isEmpty
                  ? '当前空闲'
                  : '正在推理：${ollama.activeModel}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (ollama.lastSwitch.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '最近模型切换：${ollama.lastSwitch}',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: AppColors.warning),
            ),
          ),
        if (candidates.isEmpty)
          Text('未获取到模型候选，请刷新状态',
              style: Theme.of(context).textTheme.labelSmall)
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final candidate in candidates)
                Tooltip(
                  message: candidate.installed
                      ? candidate.model
                      : '未安装：请先执行 ollama pull ${candidate.model}',
                  child: FilterChip(
                    label: Text(
                      candidate.installed
                          ? candidate.label
                          : '${candidate.label}（未安装）',
                    ),
                    selected: candidate.isCurrent,
                    // 未安装的模型不允许选中：写进设置只会让标注批次报错
                    onSelected: candidate.installed
                        ? (_) => notifier.run(
                              '已切换 VLM 标注模型：${candidate.model}',
                              () => client.updateVlmModel(
                                ref.read(opsSettingsControllerProvider),
                                candidate.model,
                              ),
                            )
                        : null,
                  ),
                ),
            ],
          ),
        const SizedBox(height: 4),
        Text(
          '换模型后该能力的旧产物会自动重排（输入档位/执行者不匹配即重排）。',
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
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
                for (final capability in status.capabilities)
                  FilterChip(
                    label: Text(capability.displayLabel),
                    selected:
                        status.autoCapabilities.contains(capability.capability),
                    onSelected: (selected) {
                      final next = [...status.autoCapabilities];
                      if (selected) {
                        if (!next.contains(capability.capability)) {
                          next.add(capability.capability);
                        }
                      } else {
                        next.remove(capability.capability);
                      }
                      notifier.run(
                        '自动处理能力已更新',
                        () => ref
                            .read(aiApiClientProvider)
                            .updateSettings(
                              ref.read(opsSettingsControllerProvider),
                              autoCapabilities: next,
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

/// 处理配置：用户会接触并调整的运行时项，写服务端配置文件后立即生效。
class _ProcessConfigCard extends ConsumerWidget {
  final AiStatus status;
  final AiBoardNotifier notifier;

  const _ProcessConfigCard({required this.status, required this.notifier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('处理配置', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              '保存在服务端配置文件里，改完立即生效、无需重启 Monarch；'
              '配置路径 ${status.configPath.isEmpty ? '（未启用）' : status.configPath}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppDimens.spacingS),
            Wrap(
              spacing: AppDimens.spacingM,
              runSpacing: AppDimens.spacingS,
              children: [
                _ConfigNumber(
                  label: '侧车空闲退出(秒)',
                  value: status.idleTimeoutSeconds,
                  options: const [30, 60, 120, 300, 600, 1800],
                  onSelected: (value) => _save(ref, idleTimeoutSeconds: value),
                ),
                _ConfigNumber(
                  label: '批次超时(秒)',
                  value: status.jobTimeoutSeconds,
                  options: const [300, 600, 900, 1800, 3600],
                  onSelected: (value) => _save(ref, jobTimeoutSeconds: value),
                ),
                _ConfigNumber(
                  label: '批大小',
                  value: status.batchSize,
                  options: const [4, 8, 16, 32, 64],
                  onSelected: (value) => _save(ref, batchSize: value),
                ),
                _ConfigNumber(
                  label: '重试上限',
                  value: status.maxAttempts,
                  options: const [1, 2, 3, 5, 10],
                  onSelected: (value) => _save(ref, maxAttempts: value),
                ),
                _ConfigNumber(
                  label: '并发批次数',
                  value: status.workers,
                  options: const [1, 2, 3, 4],
                  onSelected: (value) => _save(ref, workers: value),
                ),
                _ConfigChoice(
                  label: '推理设备',
                  value: status.device,
                  options: const {
                    'auto': '自动（优先 DirectML）',
                    'cpu': '强制 CPU',
                  },
                  onSelected: (value) => _save(ref, device: value),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '推理设备只影响执行速度与显存占用，不改变产物语义，因此不会触发重排。',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(
    WidgetRef ref, {
    int? idleTimeoutSeconds,
    int? jobTimeoutSeconds,
    int? batchSize,
    int? maxAttempts,
    int? workers,
    String? device,
  }) {
    return notifier.run(
      '处理配置已保存',
      () => ref.read(aiApiClientProvider).updateSettings(
            ref.read(opsSettingsControllerProvider),
            idleTimeoutSeconds: idleTimeoutSeconds,
            jobTimeoutSeconds: jobTimeoutSeconds,
            batchSize: batchSize,
            maxAttempts: maxAttempts,
            workers: workers,
            device: device,
          ),
    );
  }
}

class _ConfigNumber extends StatelessWidget {
  final String label;
  final int value;
  final List<int> options;
  final ValueChanged<int> onSelected;

  const _ConfigNumber({
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    // 当前值不在候选里时补一项，避免下拉框显示为空
    final items = [...options];
    if (value > 0 && !items.contains(value)) items.add(value);
    items.sort();
    return _ConfigField(
      label: label,
      child: DropdownButton<int>(
        value: value > 0 ? value : null,
        isDense: true,
        underline: const SizedBox.shrink(),
        items: [
          for (final option in items)
            DropdownMenuItem(value: option, child: Text('$option')),
        ],
        onChanged: (next) => next == null ? null : onSelected(next),
      ),
    );
  }
}

class _ConfigChoice extends StatelessWidget {
  final String label;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onSelected;

  const _ConfigChoice({
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final items = Map<String, String>.from(options);
    if (value.isNotEmpty && !items.containsKey(value)) items[value] = value;
    return _ConfigField(
      label: label,
      child: DropdownButton<String>(
        value: value.isEmpty ? null : value,
        isDense: true,
        underline: const SizedBox.shrink(),
        items: [
          for (final entry in items.entries)
            DropdownMenuItem(value: entry.key, child: Text(entry.value)),
        ],
        onChanged: (next) => next == null ? null : onSelected(next),
      ),
    );
  }
}

class _ConfigField extends StatelessWidget {
  final String label;
  final Widget child;

  const _ConfigField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 2),
        child,
      ],
    );
  }
}
