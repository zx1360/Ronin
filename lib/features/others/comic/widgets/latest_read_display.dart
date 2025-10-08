import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/comic/models/comic_progress.dart';
import 'package:torrid/features/others/comic/provider/comic_provider.dart';

/// 最近阅读展示组件
class LatestReadDisplay extends ConsumerWidget {
  const LatestReadDisplay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latestComicName = ref.watch(latestReadComicProvider);
    final progressNotifier = ref.watch(comicProgressProvider.notifier);

    return latestComicName.when(
      loading: () => _buildLoadingState(context),
      error: (e, _) => _buildErrorState(context),
      data: (comicName) {
        if (comicName == null) return _buildEmptyState(context);

        // 获取该漫画的进度
        final progress = progressNotifier.getProgress(comicName);
        return _buildLatestReadCard(
          context,
          comicName: comicName,
          progress: progress,
          onTap: () {
            // TODO: 后续添加跳转逻辑（打开漫画上次阅读记录）
            // Navigator.push(context, MaterialPageRoute(builder: (_) => ComicScrollPage(...)));
          },
        );
      },
    );
  }

  /// 加载中状态
  Widget _buildLoadingState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        // color: AppTheme.colors.surface,
        borderRadius: BorderRadius.circular(12),
        // boxShadow: [AppTheme.shadows.small],
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  /// 错误状态
  Widget _buildErrorState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        // color: AppTheme.colors.surface,
        borderRadius: BorderRadius.circular(12),
        // boxShadow: [AppTheme.shadows.small],
      ),
      child: Center(
        child: Text(
          '获取最近阅读失败',
          // style: AppTheme.textStyles.body1.copyWith(color: AppTheme.colors.error),
        ),
      ),
    );
  }

  /// 无最近阅读状态
  Widget _buildEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        // color: AppTheme.colors.surface,
        borderRadius: BorderRadius.circular(12),
        // boxShadow: [AppTheme.shadows.small],
      ),
      child: Center(
        child: Text(
          '暂无阅读记录',
          // style: AppTheme.textStyles.body1.copyWith(color: AppTheme.colors.secondaryText),
        ),
      ),
    );
  }

  /// 最近阅读卡片（有数据时展示）
  Widget _buildLatestReadCard(
    BuildContext context, {
    required String comicName,
    required ComicProgress? progress,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          // color: AppTheme.colors.surface,
          borderRadius: BorderRadius.circular(12),
          // boxShadow: [AppTheme.shadows.small],
          // border: Border(left: BorderSide(color: AppTheme.colors.primary, width: 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题
            Text(
              '最近阅读',
              // style: AppTheme.textStyles.subtitle1.copyWith(color: AppTheme.colors.primary),
            ),
            const SizedBox(height: 8),

            // 漫画名
            Text(
              comicName,
              // style: AppTheme.textStyles.title2,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),

            // 阅读进度
            Text(
              progress != null
                  ? '进度：第${progress.chapterIndex + 1}章 第${progress.pageIndex + 1}页'
                  : '未记录进度',
              // style: AppTheme.textStyles.body2.copyWith(color: AppTheme.colors.secondaryText),
            ),
            const SizedBox(height: 12),

            // 继续阅读按钮
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onTap,
                style: TextButton.styleFrom(
                  // foregroundColor: AppTheme.colors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                ),
                child: const Text('继续阅读 →'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
