import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:northstar/application/ops/providers/ops_overview_provider.dart';
import 'package:northstar/application/ops/providers/ops_settings_provider.dart';
import 'package:northstar/app/theme.dart';
import 'package:northstar/domain/ops/models/ops_overview.dart';
import 'package:northstar/domain/ops/utils/format_utils.dart';
import 'package:northstar/shared/widgets/heading/heading.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewState = ref.watch(opsOverviewControllerProvider);
    final settings = ref.watch(opsSettingsControllerProvider);
    final controller = ref.read(opsOverviewControllerProvider.notifier);

    final overview = overviewState.overview;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Heading(title: 'Dashboard'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimens.paddingL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _OnlineChip(online: overviewState.online),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        overviewState.lastUpdatedAt == null
                            ? '尚未获取到监控数据'
                            : '上次刷新: ${overviewState.lastUpdatedAt}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: overviewState.loading
                          ? null
                          : () async {
                              await controller.refresh();
                            },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('手动刷新'),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.spacingL),
                if (overviewState.errorMessage != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimens.paddingM),
                      child: Text(
                        '监控接口异常: ${overviewState.errorMessage}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: AppDimens.spacingM),
                _ServiceAndDbSection(overview: overview),
                const SizedBox(height: AppDimens.spacingL),
                Row(
                  children: [
                    Text('存储占用', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(width: 12),
                    Text(
                      '轮询间隔 ${settings.autoRefreshSeconds}s',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.spacingM),
                if (overview == null && overviewState.loading)
                  const Center(child: CircularProgressIndicator())
                else if (overview == null)
                  const Text('暂无数据')
                else
                  _StorageGrid(storage: overview.storage),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OnlineChip extends StatelessWidget {
  final bool online;

  const _OnlineChip({required this.online});

  @override
  Widget build(BuildContext context) {
    final color = online ? Colors.greenAccent.shade400 : Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        border: Border.all(color: color.withValues(alpha: 0.8)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        online ? '服务在线' : '服务离线',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _ServiceAndDbSection extends StatelessWidget {
  final OpsOverview? overview;

  const _ServiceAndDbSection({required this.overview});

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      _InfoCard(
        title: 'Monarch Service',
        icon: Icons.hub_outlined,
        lines: overview == null
            ? const <String>['未连接']
            : <String>[
                '模式: ${overview!.service.isLocalMode ? 'Local' : 'HTTPS'}',
                '端口: ${overview!.service.port?.toString() ?? '-'}',
              ],
      ),
      _InfoCard(
        title: 'Database',
        icon: Icons.storage_rounded,
        lines: overview == null
            ? const <String>['未连接']
            : <String>[
                overview!.database.reachable ? '状态: 可达' : '状态: 不可达',
                if ((overview!.database.error ?? '').isNotEmpty)
                  '错误: ${overview!.database.error}',
              ],
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth > 900;
        if (!twoColumns) {
          return Column(
            children: [
              for (final card in cards) ...[
                card,
                const SizedBox(height: 10),
              ],
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 10),
            Expanded(child: cards[1]),
          ],
        );
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> lines;

  const _InfoCard({
    required this.title,
    required this.icon,
    required this.lines,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(line, style: Theme.of(context).textTheme.bodyMedium),
              ),
          ],
        ),
      ),
    );
  }
}

class _StorageGrid extends StatelessWidget {
  final Map<String, OpsStorageOverview> storage;

  const _StorageGrid({required this.storage});

  @override
  Widget build(BuildContext context) {
    final entries = storage.entries.toList(growable: false);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 3 : 2,
        crossAxisSpacing: AppDimens.spacingM,
        mainAxisSpacing: AppDimens.spacingM,
        childAspectRatio: 1.9,
      ),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final item = entry.value;

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
                        entry.key,
                        style: Theme.of(context).textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: '复制路径',
                      onPressed: item.path.trim().isEmpty
                          ? null
                          : () async {
                              await Clipboard.setData(ClipboardData(text: item.path));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('路径已复制到剪贴板')),
                                );
                              }
                            },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                    ),
                  ],
                ),
                Text(
                  item.path,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                Text('文件数: ${item.files}'),
                Text('容量: ${formatBytes(item.bytes)}'),
                Text('存在: ${item.exists ? '是' : '否'}'),
                if (item.error != null)
                  Text(
                    '错误: ${item.error}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
