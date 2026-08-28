import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:northstar/application/comix/providers/comix_providers.dart';
import 'package:northstar/app/theme.dart';
import 'package:northstar/ui/comix/widgets/comix_widgets.dart';

/// 设置 Tab：comix 集成配置（只读展示）+ 可用站点列表。
class SettingsTab extends ConsumerWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(comixConfigProvider);
    final sites = ref.watch(comixSitesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimens.paddingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.paddingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '集成配置',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: '刷新',
                        onPressed: () {
                          ref.invalidate(comixConfigProvider);
                          ref.invalidate(comixSitesProvider);
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimens.spacingS),
                  config.when(
                    data: (cfg) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ComixStatusChip(
                              ok: cfg.available,
                              label: cfg.available ? 'comix 可用' : 'comix 不可用',
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDimens.spacingM),
                        _InfoRow(label: 'python', value: cfg.python),
                        _InfoRow(label: '配置值', value: cfg.configuredPython),
                        _InfoRow(label: '项目根目录', value: cfg.root),
                        if (!cfg.available) ...[
                          const SizedBox(height: AppDimens.spacingS),
                          Text(
                            '${cfg.message}（请在 backend/.env 中配置 COMIX_PYTHON / COMIX_ROOT）',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                    loading: () => const Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('加载配置...'),
                      ],
                    ),
                    error: (e, _) => Text(
                      '配置加载失败: $e',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimens.spacingL),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.paddingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('可用站点', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppDimens.spacingS),
                  sites.when(
                    data: (list) => Wrap(
                      spacing: AppDimens.spacingS,
                      runSpacing: AppDimens.spacingS,
                      children: [
                        for (final site in list)
                          Chip(
                            avatar: site.enabled
                                ? const Icon(Icons.check_circle, size: 16)
                                : const Icon(Icons.cancel, size: 16),
                            label: Text('${site.name} (${site.code})'),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                    loading: () => const Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('加载站点...'),
                      ],
                    ),
                    error: (e, _) => Text('站点加载失败: $e'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: SelectableText(
              value.isEmpty ? '(未配置)' : value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
