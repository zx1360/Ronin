import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/app/theme/theme_book.dart';
import 'package:torrid/core/constants/spacing.dart';
import 'package:torrid/providers/storage/cache_provider.dart';

/// 存储设置页面
///
/// 展示应用缓存占用情况，提供手动清理功能和缓存配置
class ProfileStorage extends ConsumerWidget {
  const ProfileStorage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cacheState = ref.watch(cacheManagerProvider);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // 缓存概览卡片
        _CacheOverviewCard(
          cacheState: cacheState,
          onClearAll: () => _confirmClearAll(context, ref),
        ),

        const SizedBox(height: AppSpacing.lg),

        // 缓存详情分区
        _buildSection(
          title: '缓存详情',
          children: [
            _CacheDetailTile(
              icon: Icons.image_outlined,
              title: '图片缓存',
              subtitle: '网络图片缓存',
              size: cacheState.info.formattedImageCache,
              isLoading: cacheState.isLoading,
              onClear: cacheState.isClearing
                  ? null
                  : () => _confirmClear(
                        context,
                        ref,
                        '图片缓存',
                        () =>
                            ref.read(cacheManagerProvider.notifier).clearImageCache(),
                      ),
            ),
            const Divider(height: 1),
            _CacheDetailTile(
              icon: Icons.folder_outlined,
              title: '临时文件',
              subtitle: '应用运行临时数据',
              size: cacheState.info.formattedTempCache,
              isLoading: cacheState.isLoading,
              onClear: cacheState.isClearing
                  ? null
                  : () => _confirmClear(
                        context,
                        ref,
                        '临时文件',
                        () =>
                            ref.read(cacheManagerProvider.notifier).clearTempCache(),
                      ),
            ),
            const Divider(height: 1),
            _CacheDetailTile(
              icon: Icons.storage_outlined,
              title: '其他缓存',
              subtitle: '应用缓存目录',
              size: cacheState.info.formattedOtherCache,
              isLoading: cacheState.isLoading,
              onClear: cacheState.isClearing
                  ? null
                  : () => _confirmClear(
                        context,
                        ref,
                        '其他缓存',
                        () =>
                            ref.read(cacheManagerProvider.notifier).clearOtherCache(),
                      ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.lg),

        // 自动清理设置分区
        _buildSection(
          title: '自动清理',
          children: [
            _AutoCleanToggleTile(cacheState: cacheState),
            if (cacheState.config.autoCleanEnabled) ...[
              const Divider(height: 1),
              _ExpireDaysTile(cacheState: cacheState),
              const Divider(height: 1),
              _MaxSizeTile(cacheState: cacheState),
            ],
          ],
        ),

        const SizedBox(height: AppSpacing.lg),

        // 刷新按钮
        Center(
          child: TextButton.icon(
            onPressed: cacheState.isLoading
                ? null
                : () => ref.read(cacheManagerProvider.notifier).refresh(),
            icon: cacheState.isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: const Text('刷新缓存信息'),
          ),
        ),

        // 消息提示
        if (cacheState.message != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Center(
              child: Text(
                cacheState.message!,
                style: TextStyle(
                  color: AppTheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.sm,
            bottom: AppSpacing.sm,
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
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清理所有缓存'),
        content: const Text('确定要清理所有缓存吗？这不会删除您的应用数据。'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
            ),
            child: const Text('清理'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(cacheManagerProvider.notifier).clearAllCache();
    }
  }

  Future<void> _confirmClear(
    BuildContext context,
    WidgetRef ref,
    String cacheName,
    Future<void> Function() onClear,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('清理$cacheName'),
        content: Text('确定要清理$cacheName吗？'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清理'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await onClear();
    }
  }
}

/// 缓存概览卡片
class _CacheOverviewCard extends StatelessWidget {
  final CacheState cacheState;
  final VoidCallback? onClearAll;

  const _CacheOverviewCard({
    required this.cacheState,
    this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            // 缓存总量显示
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.pie_chart_outline,
                    color: AppTheme.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '缓存占用',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      cacheState.isLoading
                          ? const SizedBox(
                              width: 80,
                              height: 24,
                              child: LinearProgressIndicator(),
                            )
                          : Text(
                              cacheState.info.formattedTotal,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                            ),
                    ],
                  ),
                ),
                // 清理按钮
                ElevatedButton.icon(
                  onPressed: cacheState.isClearing ? null : onClearAll,
                  icon: cacheState.isClearing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.delete_outline),
                  label: Text(cacheState.isClearing ? '清理中...' : '一键清理'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),

            // 容量指示条
            if (!cacheState.isLoading) ...[
              const SizedBox(height: AppSpacing.md),
              _buildCapacityIndicator(cacheState),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCapacityIndicator(CacheState cacheState) {
    final currentMB = cacheState.info.totalSize / (1024 * 1024);
    final maxMB = cacheState.config.maxSizeMB.toDouble();
    final percentage = (currentMB / maxMB).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '容量使用',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
            Text(
              '${currentMB.toStringAsFixed(1)} / ${maxMB.toInt()} MB',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage,
            minHeight: 8,
            backgroundColor: AppTheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(
              percentage > 0.8
                  ? Colors.orange
                  : percentage > 0.95
                      ? Colors.red
                      : AppTheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}

/// 缓存详情列表项
class _CacheDetailTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String size;
  final bool isLoading;
  final VoidCallback? onClear;

  const _CacheDetailTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.size,
    this.isLoading = false,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primary),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12,
          color: AppTheme.onSurfaceVariant,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading)
            const SizedBox(
              width: 60,
              height: 20,
              child: LinearProgressIndicator(),
            )
          else
            Text(
              size,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppTheme.primary,
              ),
            ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: onClear,
            tooltip: '清理',
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

/// 自动清理开关
class _AutoCleanToggleTile extends ConsumerWidget {
  final CacheState cacheState;

  const _AutoCleanToggleTile({required this.cacheState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile(
      title: const Text('启用自动清理'),
      subtitle: const Text(
        '应用启动时自动检查并清理过期缓存',
        style: TextStyle(
          fontSize: 12,
          color: AppTheme.onSurfaceVariant,
        ),
      ),
      value: cacheState.config.autoCleanEnabled,
      onChanged: (value) {
        ref.read(cacheManagerProvider.notifier).updateConfig(
              cacheState.config.copyWith(autoCleanEnabled: value),
            );
      },
    );
  }
}

/// 过期天数设置
class _ExpireDaysTile extends ConsumerWidget {
  final CacheState cacheState;

  const _ExpireDaysTile({required this.cacheState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.schedule, color: AppTheme.primary),
      title: const Text('缓存过期时间'),
      subtitle: Text(
        '超过此天数的缓存将被自动清理',
        style: const TextStyle(
          fontSize: 12,
          color: AppTheme.onSurfaceVariant,
        ),
      ),
      trailing: DropdownButton<int>(
        value: cacheState.config.expireDays,
        underline: const SizedBox(),
        items: const [
          DropdownMenuItem(value: 3, child: Text('3天')),
          DropdownMenuItem(value: 7, child: Text('7天')),
          DropdownMenuItem(value: 14, child: Text('14天')),
          DropdownMenuItem(value: 30, child: Text('30天')),
        ],
        onChanged: (value) {
          if (value != null) {
            ref.read(cacheManagerProvider.notifier).updateConfig(
                  cacheState.config.copyWith(expireDays: value),
                );
          }
        },
      ),
    );
  }
}

/// 容量上限设置
class _MaxSizeTile extends ConsumerWidget {
  final CacheState cacheState;

  const _MaxSizeTile({required this.cacheState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.sd_storage_outlined, color: AppTheme.primary),
      title: const Text('缓存容量上限'),
      subtitle: Text(
        '超过此容量将触发自动清理',
        style: const TextStyle(
          fontSize: 12,
          color: AppTheme.onSurfaceVariant,
        ),
      ),
      trailing: DropdownButton<int>(
        value: cacheState.config.maxSizeMB,
        underline: const SizedBox(),
        items: const [
          DropdownMenuItem(value: 200, child: Text('200 MB')),
          DropdownMenuItem(value: 500, child: Text('500 MB')),
          DropdownMenuItem(value: 1024, child: Text('1 GB')),
          DropdownMenuItem(value: 2048, child: Text('2 GB')),
        ],
        onChanged: (value) {
          if (value != null) {
            ref.read(cacheManagerProvider.notifier).updateConfig(
                  cacheState.config.copyWith(maxSizeMB: value),
                );
          }
        },
      ),
    );
  }
}