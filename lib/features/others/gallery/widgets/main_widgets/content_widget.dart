import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/providers/gallery_providers.dart';
import 'package:torrid/features/others/gallery/services/gallery_storage_service.dart';

/// 媒体内容展示组件
/// - 左右滑动切换前一个/后一个媒体文件
/// - 图片支持放大缩小/滑动查看
/// - 双击查看详情 (由外部处理)
class ContentWidget extends ConsumerStatefulWidget {
  /// 双击回调 - 用于查看详情
  final VoidCallback? onDoubleTap;

  const ContentWidget({
    super.key,
    this.onDoubleTap,
  });

  @override
  ConsumerState<ContentWidget> createState() => _ContentWidgetState();
}

class _ContentWidgetState extends ConsumerState<ContentWidget> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    final initialIndex = ref.read(galleryCurrentIndexProvider);
    _pageController = PageController(initialPage: initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assetsAsync = ref.watch(mediaAssetListProvider);
    final currentIndex = ref.watch(galleryCurrentIndexProvider);

    return assetsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
      error: (error, stack) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              '加载失败: $error',
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(mediaAssetListProvider),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
      data: (assets) {
        if (assets.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.photo_library_outlined, color: Colors.grey, size: 64),
                SizedBox(height: 16),
                Text(
                  '暂无媒体文件\n请在设置中下载',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        // 同步 PageController
        if (_pageController.hasClients &&
            _pageController.page?.round() != currentIndex) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_pageController.hasClients) {
              _pageController.jumpToPage(currentIndex);
            }
          });
        }

        return Stack(
          children: [
            // 主内容区 - PageView
            PageView.builder(
              controller: _pageController,
              itemCount: assets.length,
              onPageChanged: (index) {
                ref.read(galleryCurrentIndexProvider.notifier).update(index);
              },
              itemBuilder: (context, index) {
                return _MediaItemView(
                  asset: assets[index],
                  onDoubleTap: widget.onDoubleTap,
                );
              },
            ),

            // 顶部信息栏
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _TopInfoBar(
                currentIndex: currentIndex,
                total: assets.length,
                asset: assets.isNotEmpty ? assets[currentIndex] : null,
              ),
            ),

            // 底部进度指示
            Positioned(
              bottom: 8,
              left: 16,
              right: 16,
              child: _ProgressIndicator(
                current: currentIndex + 1,
                total: assets.length,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 单个媒体项视图
class _MediaItemView extends ConsumerWidget {
  final MediaAsset asset;
  final VoidCallback? onDoubleTap;

  const _MediaItemView({
    required this.asset,
    this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(galleryStorageProvider);

    return FutureBuilder<File?>(
      future: _getDisplayFile(storage),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        final file = snapshot.data;
        if (file == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.broken_image, color: Colors.grey, size: 64),
                const SizedBox(height: 8),
                Text(
                  '文件不存在',
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ],
            ),
          );
        }

        // 图片类型
        if (asset.isImage) {
          return GestureDetector(
            onDoubleTap: onDoubleTap,
            child: PhotoView(
              imageProvider: FileImage(file),
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 3,
              initialScale: PhotoViewComputedScale.contained,
              loadingBuilder: (context, event) => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              errorBuilder: (context, error, stackTrace) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 48),
                    const SizedBox(height: 8),
                    Text(
                      '加载失败',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // 视频类型 - 显示预览图 + 播放图标
        // TODO: 集成视频播放器
        if (asset.isVideo) {
          return GestureDetector(
            onDoubleTap: onDoubleTap,
            onTap: () {
              // TODO: 播放视频
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('视频播放功能开发中')),
              );
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  file,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(Icons.videocam, color: Colors.grey, size: 64),
                  ),
                ),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // 其他类型
        return const Center(
          child: Icon(Icons.insert_drive_file, color: Colors.grey, size: 64),
        );
      },
    );
  }

  /// 获取显示用的文件 (优先原图, 其次预览图, 最后缩略图)
  Future<File?> _getDisplayFile(GalleryStorageService storage) async {
    // 优先使用原图
    final mediaFile = await storage.getMediaFile(asset.filePath);
    if (mediaFile != null) return mediaFile;

    // 其次使用预览图
    if (asset.previewPath != null) {
      final previewFile = await storage.getPreviewFile(asset.previewPath!);
      if (previewFile != null) return previewFile;
    }

    // 最后使用缩略图
    if (asset.thumbPath != null) {
      final thumbFile = await storage.getThumbFile(asset.thumbPath!);
      if (thumbFile != null) return thumbFile;
    }

    return null;
  }
}

/// 顶部信息栏
class _TopInfoBar extends StatelessWidget {
  final int currentIndex;
  final int total;
  final MediaAsset? asset;

  const _TopInfoBar({
    required this.currentIndex,
    required this.total,
    this.asset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black54,
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // 文件名
            Expanded(
              child: Text(
                asset?.filePath.split('/').last.split('\\').last ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 删除标记
            if (asset?.isDeleted ?? false)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '已删除',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            // 捆绑标记
            if (asset?.groupId != null)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.layers, color: Colors.amber, size: 20),
              ),
          ],
        ),
      ),
    );
  }
}

/// 底部进度指示器
class _ProgressIndicator extends StatelessWidget {
  final int current;
  final int total;

  const _ProgressIndicator({
    required this.current,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 进度文字
        Text(
          '$current / $total',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        // 进度条
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: total > 0 ? current / total : 0,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white70),
            minHeight: 3,
          ),
        ),
      ],
    );
  }
}