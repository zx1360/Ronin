/// 数据传输页面
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:torrid/app/theme/theme_book.dart';
import 'package:torrid/core/constants/spacing.dart';
import 'package:torrid/features/profile/second_page/data/data_transfer.dart';
import 'package:torrid/providers/network_config/network_config_provider.dart';

/// 数据传输页面
///
/// 提供数据同步和备份的统一入口，包括：
/// - 服务器连接状态显示
/// - 传输进度显示
/// - 同步/备份操作按钮
class DataTransferPage extends ConsumerWidget {
  const DataTransferPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configState = ref.watch(networkConfigManagerProvider);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // 服务器连接状态卡片
        _ServerStatusCard(configState: configState),

        const SizedBox(height: AppSpacing.lg),

        // 传输进度
        const TransferProgressWidget(),

        // 同步操作区
        _buildSection(
          title: '同步到本地',
          subtitle: '从服务器下载数据到本地',
          children: const [_SyncSection()],
        ),

        const SizedBox(height: AppSpacing.lg),

        // 备份操作区
        _buildSection(
          title: '备份到服务器',
          subtitle: '将本地数据上传到服务器',
          children: const [_BackupSection()],
        ),

        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.sm,
            bottom: AppSpacing.xs,
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.primary,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.sm,
            bottom: AppSpacing.sm,
          ),
          child: Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}

/// 服务器连接状态卡片
class _ServerStatusCard extends StatelessWidget {
  final NetworkConfigState configState;

  const _ServerStatusCard({required this.configState});

  @override
  Widget build(BuildContext context) {
    final hasConfig = configState.activeConfig?.isValid ?? false;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            // 状态图标
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: hasConfig
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                hasConfig ? Icons.cloud_done : Icons.cloud_off,
                color: hasConfig ? Colors.green : Colors.orange,
                size: 24,
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // 状态信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasConfig ? '已配置服务器' : '未配置服务器',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    configState.serverAddress,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            // 配置按钮
            TextButton(
              onPressed: () {
                context.pushNamed('profile_network');
              },
              child: Text(hasConfig ? '修改' : '去配置'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 同步操作区
class _SyncSection extends ConsumerWidget {
  const _SyncSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        TransferActionButton(
          action: TransferAction(
            type: TransferType.sync,
            target: TransferTarget.all,
            label: "同步所有",
            highlighted: true,
          ),
          isAll: true,
        ),
        const SizedBox(height: AppSpacing.sm),
        TransferActionButton(
          action: TransferAction(
            type: TransferType.sync,
            target: TransferTarget.booklet,
            label: "同步打卡",
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TransferActionButton(
          action: TransferAction(
            type: TransferType.sync,
            target: TransferTarget.essay,
            label: "同步随笔",
          ),
        ),
      ],
    );
  }
}

/// 备份操作区
class _BackupSection extends ConsumerWidget {
  const _BackupSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        TransferActionButton(
          action: TransferAction(
            type: TransferType.backup,
            target: TransferTarget.all,
            label: "备份所有",
            highlighted: true,
          ),
          isAll: true,
        ),
        const SizedBox(height: AppSpacing.sm),
        TransferActionButton(
          action: TransferAction(
            type: TransferType.backup,
            target: TransferTarget.booklet,
            label: "备份打卡",
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TransferActionButton(
          action: TransferAction(
            type: TransferType.backup,
            target: TransferTarget.essay,
            label: "备份随笔",
          ),
        ),
      ],
    );
  }
}
