/// 传输进度指示器组件
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/app/theme/theme_book.dart';
import 'package:torrid/features/profile/second_page/data/data_transfer/models/transfer_progress.dart';
import 'package:torrid/features/profile/second_page/data/data_transfer/services/transfer_controller.dart';

/// 传输进度指示器组件
class TransferProgressWidget extends ConsumerWidget {
  const TransferProgressWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(transferControllerProvider);

    if (progress.isIdle) {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: _getBackgroundColor(progress.status),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(progress: progress),
          if (progress.isInProgress) _ProgressBar(progress: progress),
          _Details(progress: progress),
          if (progress.isCompleted) _Actions(progress: progress),
        ],
      ),
    );
  }

  Color _getBackgroundColor(TransferStatus status) {
    return switch (status) {
      TransferStatus.success => Colors.green.shade50,
      TransferStatus.failed => Colors.red.shade50,
      TransferStatus.retrying => Colors.orange.shade50,
      _ => AppTheme.surfaceContainer,
    };
  }
}

/// 头部组件
class _Header extends ConsumerWidget {
  final TransferProgress progress;

  const _Header({required this.progress});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _StatusIcon(status: progress.status),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${progress.typeName}${progress.targetName}数据',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  progress.message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _getStatusColor(progress.status),
                  ),
                ),
              ],
            ),
          ),
          if (progress.isCompleted)
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () =>
                  ref.read(transferControllerProvider.notifier).reset(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  Color _getStatusColor(TransferStatus status) {
    return switch (status) {
      TransferStatus.success => Colors.green.shade700,
      TransferStatus.failed => Colors.red.shade700,
      TransferStatus.retrying => Colors.orange.shade700,
      _ => Colors.grey.shade600,
    };
  }
}

/// 状态图标
class _StatusIcon extends StatelessWidget {
  final TransferStatus status;

  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      TransferStatus.preparing || TransferStatus.inProgress => const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      TransferStatus.retrying => const Icon(
        Icons.refresh,
        color: Colors.orange,
        size: 24,
      ),
      TransferStatus.success => const Icon(
        Icons.check_circle,
        color: Colors.green,
        size: 24,
      ),
      TransferStatus.failed => const Icon(
        Icons.error,
        color: Colors.red,
        size: 24,
      ),
      _ => const SizedBox(width: 24, height: 24),
    };
  }
}

/// 进度条
class _ProgressBar extends StatelessWidget {
  final TransferProgress progress;

  const _ProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.progress,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress.status == TransferStatus.retrying
                    ? Colors.orange
                    : AppTheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${progress.progressPercent}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (progress.total > 0)
                Text(
                  '${progress.current}/${progress.total}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 详细信息
class _Details extends StatelessWidget {
  final TransferProgress progress;

  const _Details({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (progress.currentMessage.isNotEmpty && progress.isInProgress)
            Text(
              progress.currentMessage,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (progress.elapsed != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '耗时: ${_formatDuration(progress.elapsed!)}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade500),
              ),
            ),
          if (progress.errorMessage != null &&
              progress.status == TransferStatus.failed)
            _ErrorMessage(message: progress.errorMessage!),
          if (progress.hasFailedItems && progress.isCompleted)
            _FailedItemsList(items: progress.failedItems),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inMinutes >= 1) {
      return '${duration.inMinutes}分${duration.inSeconds % 60}秒';
    } else if (duration.inSeconds >= 1) {
      return '${duration.inSeconds}秒';
    } else {
      return '${duration.inMilliseconds}毫秒';
    }
  }
}

/// 错误信息
class _ErrorMessage extends StatelessWidget {
  final String message;

  const _ErrorMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12, color: Colors.red.shade700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// 失败项列表
class _FailedItemsList extends StatelessWidget {
  final List<FailedItem> items;

  const _FailedItemsList({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber,
                size: 16,
                color: Colors.orange.shade700,
              ),
              const SizedBox(width: 8),
              Text(
                '${items.length} 个项目失败',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
          if (items.length <= 3) ...[
            const SizedBox(height: 4),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '• ${item.name}',
                  style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 操作按钮
class _Actions extends ConsumerWidget {
  final TransferProgress progress;

  const _Actions({required this.progress});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(transferControllerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (progress.status == TransferStatus.failed)
            TextButton.icon(
              onPressed: () => controller.execute(
                type: progress.type,
                target: progress.target,
              ),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('重试'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange.shade700,
              ),
            ),
          TextButton.icon(
            onPressed: controller.reset,
            icon: Icon(
              progress.status == TransferStatus.success
                  ? Icons.check
                  : Icons.close,
              size: 18,
            ),
            label: Text(
              progress.status == TransferStatus.success ? '完成' : '关闭',
            ),
            style: TextButton.styleFrom(
              foregroundColor: progress.status == TransferStatus.success
                  ? Colors.green.shade700
                  : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
