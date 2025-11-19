import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/app/theme_book.dart';
import 'package:torrid/providers/progress/progress_provider.dart';

class ProgressIndicatorWidget extends ConsumerWidget {
  const ProgressIndicatorWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 监听进度状态变化
    final progress = ref.watch(progressServiceProvider);

    // 如果没有进度信息或总数为0，不显示组件
    if (progress.total == 0 && progress.message.isEmpty) {
      return Center(child: CircularProgressIndicator(),);
    }

    // 计算进度百分比
    final double progressValue = progress.total > 0
        ? progress.current / progress.total
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 主要进度信息
            if (progress.message.isNotEmpty)
              Text(
                progress.message,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
        
            const SizedBox(height: 12),
        
            // 进度条
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progressValue,
                minHeight: 8,
                backgroundColor: AppTheme.surfaceContainerHighest,
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
              ),
            ),
        
            const SizedBox(height: 8),
        
            // 进度详情
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 百分比和当前任务信息
                Expanded(
                  child: Text(
                    progress.total > 0
                        ? '${(progressValue * 100).toStringAsFixed(0)}% • ${progress.currentMessage}'
                        : progress.currentMessage,
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
        
                // 进度计数器 (当前/总数)
                if (progress.total > 0)
                  Text(
                    '${progress.current}/${progress.total}',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
