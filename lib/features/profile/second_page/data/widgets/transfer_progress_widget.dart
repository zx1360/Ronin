/// 传输进度指示器组件
/// 
/// 显示数据同步/备份的进度、状态和结果。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/app/theme/theme_book.dart';
import 'package:torrid/features/profile/second_page/data/models/transfer_progress.dart';
import 'package:torrid/features/profile/second_page/data/providers/transfer_service.dart';

/// 传输进度指示器组件
class TransferProgressWidget extends ConsumerWidget {
  const TransferProgressWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(transferStateProvider);

    // 如果没有传输任务，不显示组件
    if (progress.status == TransferStatus.idle) {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.all(16),
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
          // 头部：状态图标和标题
          _buildHeader(context, progress, ref),
          
          // 进度条（仅在进行中时显示）
          if (progress.isInProgress) _buildProgressBar(progress),
          
          // 详细信息
          _buildDetails(context, progress),
          
          // 操作按钮（失败时显示重试按钮）
          if (progress.isCompleted) _buildActions(context, progress, ref),
        ],
      ),
    );
  }

  /// 获取背景色
  Color _getBackgroundColor(TransferStatus status) {
    return switch (status) {
      TransferStatus.success => Colors.green.shade50,
      TransferStatus.failed => Colors.red.shade50,
      TransferStatus.retrying => Colors.orange.shade50,
      _ => AppTheme.surfaceContainer,
    };
  }

  /// 构建头部
  Widget _buildHeader(BuildContext context, TransferProgress progress, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // 状态图标
          _buildStatusIcon(progress.status),
          const SizedBox(width: 12),
          
          // 标题和状态
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
          
          // 关闭按钮（完成后显示）
          if (progress.isCompleted)
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => ref.read(transferStateProvider.notifier).reset(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  /// 构建状态图标
  Widget _buildStatusIcon(TransferStatus status) {
    return switch (status) {
      TransferStatus.preparing ||
      TransferStatus.inProgress => const SizedBox(
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
      TransferStatus.cancelled => const Icon(
        Icons.cancel,
        color: Colors.grey,
        size: 24,
      ),
      _ => const SizedBox(width: 24, height: 24),
    };
  }

  /// 获取状态颜色
  Color _getStatusColor(TransferStatus status) {
    return switch (status) {
      TransferStatus.success => Colors.green.shade700,
      TransferStatus.failed => Colors.red.shade700,
      TransferStatus.retrying => Colors.orange.shade700,
      _ => Colors.grey.shade600,
    };
  }

  /// 构建进度条
  Widget _buildProgressBar(TransferProgress progress) {
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
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建详细信息
  Widget _buildDetails(BuildContext context, TransferProgress progress) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 当前操作
          if (progress.currentMessage.isNotEmpty && progress.isInProgress)
            Text(
              progress.currentMessage,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          
          // 耗时
          if (progress.elapsed != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '耗时: ${_formatDuration(progress.elapsed!)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade500,
                ),
              ),
            ),
          
          // 错误信息
          if (progress.errorMessage != null && progress.status == TransferStatus.failed)
            Container(
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
                      progress.errorMessage!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          
          // 失败项目列表
          if (progress.hasFailedItems && progress.isCompleted)
            _buildFailedItemsList(context, progress.failedItems),
        ],
      ),
    );
  }

  /// 构建失败项目列表
  Widget _buildFailedItemsList(BuildContext context, List<FailedItem> items) {
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
              Icon(Icons.warning_amber, size: 16, color: Colors.orange.shade700),
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
            ...items.map((item) => Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '• ${item.name}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.orange.shade800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            )),
          ],
        ],
      ),
    );
  }

  /// 构建操作按钮
  Widget _buildActions(BuildContext context, TransferProgress progress, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // 重试按钮（仅失败时显示）
          if (progress.status == TransferStatus.failed)
            TextButton.icon(
              onPressed: () => _retryTransfer(ref, progress),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('重试'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange.shade700,
              ),
            ),
          
          // 确认按钮
          TextButton.icon(
            onPressed: () => ref.read(transferStateProvider.notifier).reset(),
            icon: Icon(
              progress.status == TransferStatus.success
                  ? Icons.check
                  : Icons.close,
              size: 18,
            ),
            label: Text(progress.status == TransferStatus.success ? '完成' : '关闭'),
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

  /// 重试传输
  void _retryTransfer(WidgetRef ref, TransferProgress progress) {
    // 根据传输类型和目标重新触发对应的provider
    switch (progress.target) {
      case TransferTarget.booklet:
        if (progress.type == TransferType.sync) {
          ref.invalidate(syncBookletWithProgressProvider);
        } else {
          ref.invalidate(backupBookletWithProgressProvider);
        }
        break;
      case TransferTarget.essay:
        if (progress.type == TransferType.sync) {
          ref.invalidate(syncEssayWithProgressProvider);
        } else {
          ref.invalidate(backupEssayWithProgressProvider);
        }
        break;
      case TransferTarget.all:
        if (progress.type == TransferType.sync) {
          ref.invalidate(syncAllWithProgressProvider);
        } else {
          ref.invalidate(backupAllWithProgressProvider);
        }
        break;
    }
  }

  /// 格式化时长
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

/// 简洁版传输状态提示组件（用于显示在底部）
class TransferStatusBanner extends ConsumerWidget {
  const TransferStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(transferStateProvider);

    if (progress.status == TransferStatus.idle) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: _getBannerColor(progress.status),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (progress.isInProgress)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else
              Icon(
                _getBannerIcon(progress.status),
                size: 16,
                color: Colors.white,
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                progress.isInProgress
                    ? '${progress.message} ${progress.progressPercent}%'
                    : progress.message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (progress.isCompleted)
              TextButton(
                onPressed: () => ref.read(transferStateProvider.notifier).reset(),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('关闭', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }

  Color _getBannerColor(TransferStatus status) {
    return switch (status) {
      TransferStatus.success => Colors.green,
      TransferStatus.failed => Colors.red,
      TransferStatus.retrying => Colors.orange,
      _ => AppTheme.primary,
    };
  }

  IconData _getBannerIcon(TransferStatus status) {
    return switch (status) {
      TransferStatus.success => Icons.check_circle,
      TransferStatus.failed => Icons.error,
      TransferStatus.cancelled => Icons.cancel,
      _ => Icons.info,
    };
  }
}
