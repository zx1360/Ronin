import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/core/constants/spacing.dart';
import 'package:torrid/features/others/gallery/models/gallery_overview.dart';
import 'package:torrid/features/others/gallery/providers/gallery_providers.dart';
import 'package:torrid/features/others/gallery/providers/settings_providers.dart';
import 'package:torrid/features/others/gallery/services/gallery_sync_service.dart';

class GallerySettingPage extends ConsumerStatefulWidget {
  const GallerySettingPage({super.key});

  @override
  ConsumerState<GallerySettingPage> createState() => _GallerySettingPageState();
}

class _GallerySettingPageState extends ConsumerState<GallerySettingPage> {
  // 下载数量控制
  final TextEditingController _downloadLimitController =
      TextEditingController(text: '200');
  bool _isRefreshingStorage = false;

  @override
  void dispose() {
    _downloadLimitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dbStatsAsync = ref.watch(galleryDbStatsProvider);
    final storageStats = ref.watch(galleryCachedStorageStatsProvider);
    final uploadStatsAsync = ref.watch(galleryUploadStatsProvider);
    final syncProgress = ref.watch(gallerySyncServiceProvider);
    final serverOverviewAsync = ref.watch(galleryServerOverviewProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("媒体管理设置")),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.sm),
        children: [
          // 服务端数据总览
          _buildServerOverviewCard(context, serverOverviewAsync),

          const SizedBox(height: AppSpacing.sm),

          // 下载筛选设置
          _buildDownloadFilterCard(context),

          const SizedBox(height: AppSpacing.sm),

          // 基本信息呈现
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "本地存储情况",
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  dbStatsAsync.when(
                    loading: () => const Text("加载中...", style: TextStyle(fontSize: 12)),
                    error: (e, _) => Text("错误: $e", style: const TextStyle(fontSize: 12)),
                    data: (stats) => Text(
                      "DB: ${stats.mediaAssetCount}条媒体 / ${stats.tagCount}标签 / ${stats.mediaTagLinkCount}关联",
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "文件: ${storageStats.fileCount}个 / ${storageStats.formattedSize}",
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      _isRefreshingStorage
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              icon: const Icon(Icons.refresh, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: _handleRefreshStorageStats,
                            ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // 显示设置
          Card(
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 0),
              dense: true,
              secondary: const Icon(Icons.picture_in_picture_alt, size: 20),
              title: const Text("预览小窗", style: TextStyle(fontSize: 14)),
              subtitle: const Text("显示下一个媒体文件的缩略图预览", style: TextStyle(fontSize: 11)),
              value: ref.watch(galleryPreviewWindowEnabledProvider),
              onChanged: (value) {
                ref.read(galleryPreviewWindowEnabledProvider.notifier).setEnabled(value);
              },
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // 数据同步区
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("数据同步", style: Theme.of(context).textTheme.titleSmall),

                  // 同步进度显示
                  if (syncProgress.status != SyncStatus.idle)
                    _buildSyncProgressIndicator(syncProgress),

                  // 下载一批媒体文件
                  Row(
                    children: [
                      const Icon(Icons.cloud_download, size: 20),
                      const SizedBox(width: 8),
                      const Text("下载:", style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 60,
                        child: TextField(
                          controller: _downloadLimitController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                            hintText: '200',
                          ),
                        ),
                      ),
                      const Text(" 条", style: TextStyle(fontSize: 13)),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: syncProgress.status != SyncStatus.downloading &&
                                syncProgress.status != SyncStatus.uploading
                            ? _handleDownload
                            : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                        ),
                        child: const Text("下载", style: TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),

                  const Divider(height: AppSpacing.sm + 8),

                  // 上传本地数据
                  Row(
                    children: [
                      const Icon(Icons.cloud_upload, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: uploadStatsAsync.when(
                          loading: () => const Text("加载中...", style: TextStyle(fontSize: 12)),
                          error: (e, _) => Text("错误: $e", style: const TextStyle(fontSize: 12)),
                          data: (stats) {
                            final currentIndex = ref.watch(galleryCurrentIndexProvider);
                            final uploadCount = currentIndex + 1;
                            return Text(
                              "media_assets: $uploadCount 条 + 全量tags/links",
                              style: const TextStyle(fontSize: 12),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: syncProgress.status != SyncStatus.downloading &&
                                syncProgress.status != SyncStatus.uploading &&
                                (uploadStatsAsync.valueOrNull?.hasData ?? false)
                            ? _handleUpload
                            : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                        ),
                        child: const Text("上传", style: TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // 危险操作区
          Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "危险操作",
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: Colors.red),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: const Icon(Icons.delete_forever, color: Colors.red, size: 20),
                    title: const Text("清空数据库", style: TextStyle(fontSize: 13)),
                    subtitle: const Text("删除所有记录", style: TextStyle(fontSize: 11)),
                    onTap: _handleClearDatabase,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: const Icon(Icons.folder_delete, color: Colors.red, size: 20),
                    title: const Text("清空文件夹", style: TextStyle(fontSize: 13)),
                    subtitle: const Text("删除 /gallery/ 下所有文件", style: TextStyle(fontSize: 11)),
                    onTap: _handleClearFiles,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: const Icon(Icons.delete_sweep, color: Colors.red, size: 20),
                    title: const Text("清空所有数据", style: TextStyle(fontSize: 13)),
                    subtitle: const Text("完全重置", style: TextStyle(fontSize: 11)),
                    onTap: _handleClearAll,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建服务端数据总览卡片
  Widget _buildServerOverviewCard(
      BuildContext context, AsyncValue<GalleryOverview> overviewAsync) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text("服务端总览", style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                GestureDetector(
                  onTap: () => ref.invalidate(galleryServerOverviewProvider),
                  child: const Icon(Icons.refresh, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 4),
            overviewAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (e, _) => Text(
                "加载失败: $e",
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
              data: (overview) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 文件统计行
                  Wrap(
                    spacing: 12,
                    runSpacing: 2,
                    children: [
                      _statChip("文件总数", "${overview.totalMedia}"),
                      _statChip("图片", "${overview.imageCount} (${overview.imagePercent})"),
                      _statChip("视频", "${overview.videoCount} (${overview.videoPercent})"),
                      _statChip("总大小", overview.formattedSize),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // 标签统计行
                  Wrap(
                    spacing: 12,
                    runSpacing: 2,
                    children: [
                      _statChip("标签", "${overview.totalTags}"),
                      _statChip("根标签", "${overview.rootTags}"),
                      _statChip("关联数", "${overview.totalLinks}"),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // 同步统计行
                  Wrap(
                    spacing: 12,
                    runSpacing: 2,
                    children: [
                      _statChip("最小同步", "${overview.syncStats.minSyncCount}"),
                      _statChip("最大同步", "${overview.syncStats.maxSyncCount}"),
                      _statChip("平均同步", overview.syncStats.avgSyncCount.toStringAsFixed(1)),
                    ],
                  ),
                  // 年份分布
                  if (overview.yearStats.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 2,
                      children: overview.yearStats
                          .take(6) // 最多显示6个年份
                          .map((ys) => _statChip("${ys.year}年", "${ys.mediaCount}条"))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String label, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 12, color: Colors.black87),
        children: [
          TextSpan(
            text: "$label: ",
            style: const TextStyle(color: Colors.grey),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }

  /// 构建下载筛选设置卡片
  Widget _buildDownloadFilterCard(BuildContext context) {
    final mimeFilter = ref.watch(galleryDownloadMimeFilterProvider);
    final sortBy = ref.watch(galleryDownloadSortByProvider);
    final sortOrder = ref.watch(galleryDownloadSortOrderProvider);
    final filterYear = ref.watch(galleryDownloadYearProvider);
    final filterMonth = ref.watch(galleryDownloadMonthProvider);
    final filterDay = ref.watch(galleryDownloadDayProvider);
    final serverOverview = ref.watch(galleryServerOverviewProvider).valueOrNull;

    // 动态年份范围：服务端最早年份 ~ 今年
    final int minYear = serverOverview?.minYear ?? 2000;
    final int maxYear = DateTime.now().year;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("下载筛选", style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),

            // MIME类型筛选
            Row(
              children: [
                const Text("类型:", style: TextStyle(fontSize: 12)),
                const SizedBox(width: 8),
                _FilterChip(
                  label: "全部",
                  selected: mimeFilter.isEmpty,
                  onTap: () => ref.read(galleryDownloadMimeFilterProvider.notifier).set(''),
                ),
                _FilterChip(
                  label: "图片",
                  selected: mimeFilter == 'image',
                  onTap: () => ref.read(galleryDownloadMimeFilterProvider.notifier).set('image'),
                ),
                _FilterChip(
                  label: "视频",
                  selected: mimeFilter == 'video',
                  onTap: () => ref.read(galleryDownloadMimeFilterProvider.notifier).set('video'),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // 排序方式
            Row(
              children: [
                const Text("排序:", style: TextStyle(fontSize: 12)),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    isDense: true,
                    value: sortBy.isEmpty ? 'default' : sortBy,
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                    items: const [
                      DropdownMenuItem(value: 'default', child: Text("默认")),
                      DropdownMenuItem(value: 'captured_at', child: Text("文件日期")),
                      DropdownMenuItem(value: 'size_bytes', child: Text("文件大小")),
                    ],
                    onChanged: (v) {
                      ref.read(galleryDownloadSortByProvider.notifier)
                          .set(v == 'default' ? '' : v!);
                    },
                  ),
                ),
                const SizedBox(width: 4),
                _FilterChip(
                  label: sortOrder == 'asc' ? "↑升" : "↓降",
                  selected: true,
                  onTap: () {
                    ref.read(galleryDownloadSortOrderProvider.notifier)
                        .set(sortOrder == 'asc' ? 'desc' : 'asc');
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),

            // 日期筛选行
            Row(
              children: [
                const Text("日期:", style: TextStyle(fontSize: 12)),
                const SizedBox(width: 8),
                _buildYearDropdown(filterYear, minYear, maxYear),
                const Text("年", style: TextStyle(fontSize: 12)),
                const SizedBox(width: 4),
                if (filterYear > 0) ...[
                  _buildMonthDropdown(filterMonth),
                  const Text("月", style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  if (filterMonth > 0) ...[
                    _buildDayDropdown(filterDay),
                    const Text("日", style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                  ],
                ],
                if (filterYear > 0)
                  TextButton.icon(
                    onPressed: () {
                      ref.read(galleryDownloadYearProvider.notifier).set(0);
                      ref.read(galleryDownloadMonthProvider.notifier).set(0);
                      ref.read(galleryDownloadDayProvider.notifier).set(0);
                    },
                    icon: const Icon(Icons.clear, size: 12),
                    label: const Text("清除", style: TextStyle(fontSize: 11)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: Size.zero,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 4),
            Text(
              "注意: 修改筛选条件后需重新点击\"下载\"生效",
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYearDropdown(int currentYear, int minYear, int maxYear) {
    final years = List.generate(maxYear - minYear + 1, (i) => maxYear - i);

    return SizedBox(
      width: 68,
      child: DropdownButton<int>(
        isExpanded: true,
        isDense: true,
        iconSize: 16,
        value: currentYear,
        style: const TextStyle(fontSize: 12, color: Colors.black87),
        items: [
          const DropdownMenuItem(value: 0, child: Text('全部', style: TextStyle(fontSize: 12))),
          ...years.map((y) => DropdownMenuItem(value: y, child: Text('$y', style: const TextStyle(fontSize: 12)))),
        ],
        onChanged: (v) {
          if (v == null) return;
          ref.read(galleryDownloadYearProvider.notifier).set(v);
          if (v == 0) {
            ref.read(galleryDownloadMonthProvider.notifier).set(0);
            ref.read(galleryDownloadDayProvider.notifier).set(0);
          }
        },
      ),
    );
  }

  Widget _buildMonthDropdown(int currentMonth) {
    return SizedBox(
      width: 56,
      child: DropdownButton<int>(
        isExpanded: true,
        isDense: true,
        iconSize: 16,
        value: currentMonth,
        style: const TextStyle(fontSize: 12, color: Colors.black87),
        items: [
          const DropdownMenuItem(value: 0, child: Text('不限', style: TextStyle(fontSize: 12))),
          ...List.generate(12, (i) => i + 1)
              .map((m) => DropdownMenuItem(value: m, child: Text('$m', style: const TextStyle(fontSize: 12)))),
        ],
        onChanged: (v) {
          if (v == null) return;
          ref.read(galleryDownloadMonthProvider.notifier).set(v);
          if (v == 0) ref.read(galleryDownloadDayProvider.notifier).set(0);
        },
      ),
    );
  }

  Widget _buildDayDropdown(int currentDay) {
    return SizedBox(
      width: 56,
      child: DropdownButton<int>(
        isExpanded: true,
        isDense: true,
        iconSize: 16,
        value: currentDay,
        style: const TextStyle(fontSize: 12, color: Colors.black87),
        items: [
          const DropdownMenuItem(value: 0, child: Text('不限', style: TextStyle(fontSize: 12))),
          ...List.generate(31, (i) => i + 1)
              .map((d) => DropdownMenuItem(value: d, child: Text('$d', style: const TextStyle(fontSize: 12)))),
        ],
        onChanged: (v) {
          if (v == null) return;
          ref.read(galleryDownloadDayProvider.notifier).set(v);
        },
      ),
    );
  }

  /// 构建同步进度指示器
  Widget _buildSyncProgressIndicator(SyncProgress progress) {
    Color color;
    IconData icon;
    
    switch (progress.status) {
      case SyncStatus.downloading:
        color = Colors.blue;
        icon = Icons.cloud_download;
        break;
      case SyncStatus.uploading:
        color = Colors.green;
        icon = Icons.cloud_upload;
        break;
      case SyncStatus.success:
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case SyncStatus.error:
        color = Colors.red;
        icon = Icons.error;
        break;
      default:
        color = Colors.grey;
        icon = Icons.sync;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  progress.message ?? '',
                  style: TextStyle(color: color),
                ),
              ),
              if (progress.status == SyncStatus.downloading ||
                  progress.status == SyncStatus.uploading)
                TextButton(
                  onPressed: () {
                    ref.read(gallerySyncServiceProvider.notifier).cancel();
                  },
                  child: const Text('取消'),
                ),
            ],
          ),
          if (progress.total > 0) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress.progress,
              backgroundColor: color.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
            const SizedBox(height: 4),
            Text(
              '${progress.current} / ${progress.total}',
              style: TextStyle(fontSize: 12, color: color),
            ),
          ],
          if (progress.error != null) ...[
            const SizedBox(height: 8),
            Text(
              progress.error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  /// 刷新文件存储统计
  Future<void> _handleRefreshStorageStats() async {
    setState(() => _isRefreshingStorage = true);
    try {
      await ref.read(galleryCachedStorageStatsProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '文件统计已刷新: '
              '${ref.read(galleryCachedStorageStatsProvider).fileCount} 个文件, '
              '${ref.read(galleryCachedStorageStatsProvider).formattedSize}',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('刷新失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshingStorage = false);
    }
  }

  /// 处理下载
  Future<void> _handleDownload() async {
    final limit = int.tryParse(_downloadLimitController.text) ?? 200;
    await ref.read(gallerySyncServiceProvider.notifier).downloadBatch(limit: limit);
    
    // 刷新统计数据
    ref.invalidate(galleryDbStatsProvider);
    ref.invalidate(galleryUploadStatsProvider);
    try {
      await ref.read(galleryCachedStorageStatsProvider.notifier).refresh();
    } catch (_) {}
  }

  /// 处理上传
  Future<void> _handleUpload() async {
    final confirmed = await _showConfirmDialog(
      title: '确认上传',
      content: '上传后将清空本地数据，确定继续？',
    );

    if (confirmed) {
      await ref.read(gallerySyncServiceProvider.notifier).uploadData();
      
      // 刷新统计数据（异步，不阻塞 UI）
      ref.invalidate(galleryDbStatsProvider);
      ref.invalidate(galleryUploadStatsProvider);
      // 文件扫描较慢，fire-and-forget 避免阻塞
      unawaited(ref.read(galleryCachedStorageStatsProvider.notifier).refresh()
          .catchError((_) {}));
    }
  }

  /// 处理清空数据库
  Future<void> _handleClearDatabase() async {
    final confirmed = await _showConfirmDialog(
      title: '清空数据库',
      content: '确定要清空所有数据库记录吗？此操作不可恢复！',
      isDangerous: true,
    );

    if (confirmed) {
      final db = ref.read(galleryDatabaseProvider);
      await db.clearAllData();
      
      // 重置状态
      await ref.read(galleryModifiedCountProvider.notifier).reset();
      await ref.read(galleryCurrentIndexProvider.notifier).update(0);
      
      // 刷新数据
      ref.invalidate(mediaAssetListProvider);
      ref.invalidate(tagTreeProvider);
      ref.invalidate(galleryDbStatsProvider);
      ref.invalidate(galleryUploadStatsProvider);

    }
  }

  /// 处理清空文件
  Future<void> _handleClearFiles() async {
    final confirmed = await _showConfirmDialog(
      title: '清空文件夹',
      content: '确定要清空所有媒体文件吗？此操作不可恢复！',
      isDangerous: true,
    );

    if (confirmed) {
      final storage = ref.read(galleryStorageProvider);
      await storage.clearAllFiles();
      
      // 刷新数据
      try {
        await ref.read(galleryCachedStorageStatsProvider.notifier).refresh();
      } catch (_) {}

    }
  }

  /// 处理清空所有数据
  Future<void> _handleClearAll() async {
    final confirmed = await _showConfirmDialog(
      title: '清空所有数据',
      content: '确定要清空数据库和所有文件吗？此操作不可恢复！',
      isDangerous: true,
    );

    if (confirmed) {
      final db = ref.read(galleryDatabaseProvider);
      final storage = ref.read(galleryStorageProvider);
      
      await db.clearAllData();
      await storage.clearAllFiles();
      
      // 重置状态
      await ref.read(galleryModifiedCountProvider.notifier).reset();
      await ref.read(galleryCurrentIndexProvider.notifier).update(0);
      
      // 刷新数据
      ref.invalidate(mediaAssetListProvider);
      ref.invalidate(tagTreeProvider);
      ref.invalidate(galleryDbStatsProvider);
      ref.invalidate(galleryUploadStatsProvider);
      try {
        await ref.read(galleryCachedStorageStatsProvider.notifier).refresh();
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('所有数据已清空')),
        );
      }
    }
  }

  /// 显示确认对话框
  Future<bool> _showConfirmDialog({
    required String title,
    required String content,
    bool isDangerous = false,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              ElevatedButton(
                style: isDangerous
                    ? ElevatedButton.styleFrom(backgroundColor: Colors.red)
                    : null,
                onPressed: () => Navigator.pop(context, true),
                child: const Text('确定'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

/// 小型筛选芯片
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Material(
        color: selected
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[700],
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
