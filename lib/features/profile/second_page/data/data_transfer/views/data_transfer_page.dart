/// 数据传输页面
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/profile/second_page/data/data_transfer/data_transfer.dart';
import 'package:torrid/providers/server_connect/server_conn_provider.dart';

/// 数据传输页面
///
/// 提供数据同步和备份的统一入口，包括：
/// - 网络配置
/// - 传输进度显示
/// - 同步/备份操作按钮
class DataTransferPage extends ConsumerWidget {
  const DataTransferPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final serverState = ref.watch(serverConnectorProvider);
    final isLoading = serverState['isLoading'] as bool;

    if (isLoading) {
      return _buildLoadingState(theme);
    }

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 网络配置
            const NetworkConfigWidget(),

            // 传输进度
            const TransferProgressWidget(),

            // 同步操作区
            _SectionHeader(title: "同步到本地:", theme: theme),
            const _SyncSection(),

            const SizedBox(height: 24),

            // 备份操作区
            _SectionHeader(title: "更新到外部:", theme: theme),
            const _BackupSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
          ),
          const SizedBox(height: 16),
          const Text("稍等...", style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}

/// 区块标题
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.theme});

  final String title;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.primary,
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
        const SizedBox(height: 8),
        TransferActionButton(
          action: TransferAction(
            type: TransferType.sync,
            target: TransferTarget.all,
            label: "同步所有",
            highlighted: true,
          ),
          isAll: true,
        ),
        const SizedBox(height: 8),
        TransferActionButton(
          action: TransferAction(
            type: TransferType.sync,
            target: TransferTarget.booklet,
            label: "同步打卡",
          ),
        ),
        const SizedBox(height: 8),
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
        const SizedBox(height: 8),
        TransferActionButton(
          action: TransferAction(
            type: TransferType.backup,
            target: TransferTarget.all,
            label: "备份所有",
            highlighted: true,
          ),
          isAll: true,
        ),
        const SizedBox(height: 8),
        TransferActionButton(
          action: TransferAction(
            type: TransferType.backup,
            target: TransferTarget.booklet,
            label: "备份打卡",
          ),
        ),
        const SizedBox(height: 8),
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
