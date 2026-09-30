import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:northstar/app/theme.dart';
import 'package:northstar/core/providers/ai/ai_providers.dart';
import 'package:northstar/core/providers/ops/ops_settings_provider.dart';
import 'package:northstar/domain/ai/models/ai_models.dart';
import 'package:northstar/ui/ai/widgets/ai_widgets.dart';

/// 任务列表：按能力/状态过滤，支持一键重试失败任务。
///
/// 能力过滤项由服务端状态下发（`/API/ai/status` 的 capabilities），端上不硬编码能力清单。
class AiJobsTab extends ConsumerStatefulWidget {
  const AiJobsTab({super.key});

  @override
  ConsumerState<AiJobsTab> createState() => _AiJobsTabState();
}

class _AiJobsTabState extends ConsumerState<AiJobsTab> {
  String _capability = '';
  String _status = '';

  @override
  Widget build(BuildContext context) {
    final filter = (capability: _capability, status: _status);
    final async = ref.watch(aiJobsProvider(filter));
    final capabilities = ref.watch(aiBoardProvider).status?.capabilities ?? const [];

    return Padding(
      padding: const EdgeInsets.all(AppDimens.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _FilterGroup(
                label: '能力',
                options: {
                  '': '全部',
                  for (final capability in capabilities)
                    capability.capability: capability.displayLabel,
                },
                value: _capability,
                onChanged: (value) => setState(() => _capability = value),
              ),
              _FilterGroup(
                label: '状态',
                options: const {
                  '': '全部',
                  'pending': '待处理',
                  'running': '执行中',
                  'done': '已完成',
                  'failed': '失败',
                },
                value: _status,
                onChanged: (value) => setState(() => _status = value),
              ),
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(aiJobsProvider),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('刷新'),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _retryFailed(),
                icon: const Icon(Icons.replay_rounded, size: 16),
                label: Text('重试失败${_capability.isEmpty ? '（全部能力）' : ''}'),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spacingS),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text(
                  error.toString(),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
              data: (data) {
                if (data.jobs.isEmpty) {
                  return const Center(child: Text('没有符合条件的任务'));
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('共 ${data.total} 条（显示前 ${data.jobs.length} 条）',
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: AppDimens.spacingXS),
                    Expanded(
                      child: ListView.separated(
                        itemCount: data.jobs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) =>
                            _JobRow(job: data.jobs[index]),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _retryFailed() async {
    final client = ref.read(aiApiClientProvider);
    final settings = ref.read(opsSettingsControllerProvider);
    final count = await client.retry(
      settings,
      capability: _capability.isEmpty ? null : _capability,
    );
    ref.invalidate(aiJobsProvider);
    ref.invalidate(aiBoardProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已重新排队 $count 条失败任务')),
    );
  }
}

class _FilterGroup extends StatelessWidget {
  final String label;
  final Map<String, String> options;
  final String value;
  final ValueChanged<String> onChanged;

  const _FilterGroup({
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(width: 6),
        DropdownButton<String>(
          value: value,
          isDense: true,
          underline: const SizedBox.shrink(),
          items: [
            for (final entry in options.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: (next) => onChanged(next ?? ''),
        ),
      ],
    );
  }
}

/// 一条任务行。
class _JobRow extends ConsumerWidget {
  final AiJob job;

  const _JobRow({required this.job});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capability =
        ref.watch(aiBoardProvider).status?.capabilityOf(job.capability);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(AiCapabilityIcon.of(job.capability),
              size: 14, color: AppColors.onSurfaceVariant),
          const SizedBox(width: 8),
          SizedBox(
            width: 96,
            child:
                Text(capability?.displayLabel ?? job.capability, style: _small(context)),
          ),
          SizedBox(
            width: 88,
            child: Text(
              _statusLabel(job.status),
              style: _small(context)?.copyWith(
                color: _statusColor(context, job.status),
              ),
            ),
          ),
          SizedBox(
            width: 96,
            child: Text('媒体 ${job.mediaId.substring(0, 8)}',
                style: _small(context)),
          ),
          SizedBox(
            width: 64,
            child: Text('尝试 ${job.attempts}', style: _small(context)),
          ),
          // 执行时使用的输入档位/执行者（历史任务未记录时显示 -）
          SizedBox(
            width: 180,
            child: Tooltip(
              message: job.inputSig ?? '',
              child: Text(job.inputSig ?? '-', style: _small(context)),
            ),
          ),
          Expanded(
            child: Text(
              job.lastError ?? '',
              style: _small(context)?.copyWith(color: AppColors.warning),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  TextStyle? _small(BuildContext context) =>
      Theme.of(context).textTheme.bodySmall;

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return '待处理';
      case 'running':
        return '执行中';
      case 'done':
        return '已完成';
      case 'failed':
        return '失败';
      default:
        return status;
    }
  }

  Color _statusColor(BuildContext context, String status) {
    switch (status) {
      case 'done':
        return AppColors.success;
      case 'failed':
        return Theme.of(context).colorScheme.error;
      case 'running':
        return AppColors.info;
      default:
        return AppColors.onSurfaceVariant;
    }
  }
}
