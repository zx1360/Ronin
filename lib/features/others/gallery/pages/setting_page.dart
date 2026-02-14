import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/core/constants/spacing.dart';
import 'package:torrid/features/others/gallery/providers/gallery_providers.dart';
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

  @override
  void dispose() {
    _downloadLimitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dbStatsAsync = ref.watch(galleryDbStatsProvider);
    final storageStatsAsync = ref.watch(galleryStorageStatsProvider);
    final uploadStatsAsync = ref.watch(galleryUploadStatsProvider);
    final syncProgress = ref.watch(gallerySyncServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("媒体管理设置")),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // 基本信息呈现
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "本地存储情况",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.storage),
                    title: const Text("数据库占用:"),
                    subtitle: dbStatsAsync.when(
                      loading: () => const Text("加载中..."),
                      error: (e, _) => Text("错误: $e"),
                      data: (stats) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("media_assets: ${stats.mediaAssetCount} 条"),
                          Text("tags: ${stats.tagCount} 条"),
                          Text("media_tag_links: ${stats.mediaTagLinkCount} 条"),
                        ],
                      ),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.folder),
                    title: const Text("文件系统占用:"),
                    subtitle: storageStatsAsync.when(
                      loading: () => const Text("加载中..."),
                      error: (e, _) => Text("错误: $e"),
                      data: (stats) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("文件数量: ${stats.fileCount}"),
                          Text("占用大小: ${stats.formattedSize}"),
                        ],
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () {
                        ref.invalidate(galleryStorageStatsProvider);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // 数据同步区
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("数据同步", style: Theme.of(context).textTheme.titleMedium),
                  
                  // 同步进度显示
                  if (syncProgress.status != SyncStatus.idle)
                    _buildSyncProgressIndicator(syncProgress),

                  // 下载一批媒体文件
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.cloud_download),
                    title: const Text("下载一批媒体文件"),
                    subtitle: Row(
                      children: [
                        const Text("数量: "),
                        SizedBox(
                          width: 100,
                          child: TextField(
                            controller: _downloadLimitController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    trailing: ElevatedButton(
                      onPressed: syncProgress.status != SyncStatus.downloading &&
                              syncProgress.status != SyncStatus.uploading
                          ? _handleDownload
                          : null,
                      child: const Text("下载"),
                    ),
                  ),

                  const Divider(),

                  // 上传本地数据
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.cloud_upload),
                    title: const Text("上传本地数据"),
                    subtitle: uploadStatsAsync.when(
                      loading: () => const Text("加载中..."),
                      error: (e, _) => Text("错误: $e"),
                      data: (stats) {
                        final currentIndex = ref.watch(galleryCurrentIndexProvider);
                        final allAssets = ref.watch(mediaAssetListProvider).valueOrNull ?? [];
                        final uploadCount = currentIndex + 1;
                        // 计算前 uploadCount 条记录中被标记删除的数量
                        final deletedCount = allAssets
                            .take(uploadCount.clamp(0, allAssets.length))
                            .where((a) => a.isDeleted)
                            .length;
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("media_assets: $uploadCount 条"),
                            Text("以及全量tags和关联media_tag_links."),
                            Text("其中标记删除条数: $deletedCount"),
                          ],
                        );
                      },
                    ),
                    trailing: ElevatedButton(
                      onPressed: syncProgress.status != SyncStatus.downloading &&
                              syncProgress.status != SyncStatus.uploading &&
                              (uploadStatsAsync.valueOrNull?.hasData ?? false)
                          ? _handleUpload
                          : null,
                      child: const Text("上传"),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // 危险操作区
          Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "危险操作",
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: Colors.red),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.delete_forever, color: Colors.red),
                    title: const Text("清空相关 sqflite 数据表"),
                    subtitle: const Text("删除所有媒体文件及其标签和关联数据"),
                    onTap: _handleClearDatabase,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.folder_delete, color: Colors.red),
                    title: const Text("清空媒体文件夹"),
                    subtitle: const Text("删除 /gallery/ 下的所有文件"),
                    onTap: _handleClearFiles,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.delete_sweep, color: Colors.red),
                    title: const Text("清空所有数据"),
                    subtitle: const Text("清空数据库和文件夹（完全重置）"),
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
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
              backgroundColor: color.withOpacity(0.2),
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

  /// 处理下载
  Future<void> _handleDownload() async {
    final limit = int.tryParse(_downloadLimitController.text) ?? 200;
    await ref.read(gallerySyncServiceProvider.notifier).downloadBatch(limit: limit);
    
    // 刷新统计数据
    ref.invalidate(galleryDbStatsProvider);
    ref.invalidate(galleryStorageStatsProvider);
    ref.invalidate(galleryUploadStatsProvider);
  }

  /// 处理上传
  Future<void> _handleUpload() async {
    final confirmed = await _showConfirmDialog(
      title: '确认上传',
      content: '上传后将清空本地数据，确定继续？',
    );

    if (confirmed) {
      await ref.read(gallerySyncServiceProvider.notifier).uploadData();
      
      // 刷新统计数据
      ref.invalidate(galleryDbStatsProvider);
      ref.invalidate(galleryStorageStatsProvider);
      ref.invalidate(galleryUploadStatsProvider);
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
      ref.invalidate(galleryStorageStatsProvider);

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
      ref.invalidate(galleryStorageStatsProvider);
      ref.invalidate(galleryUploadStatsProvider);

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
