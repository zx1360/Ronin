import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/providers/gallery_providers.dart';
import 'package:torrid/features/others/gallery/services/gallery_storage_service.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';
import 'package:video_player/video_player.dart';

/// 媒体内容展示组件
/// - 显示当前媒体文件 (图片/视频)
/// - 图片支持双指缩放/滑动查看
/// - 手势区域:
///   - 左 1/4 点击: 上一张
///   - 右 1/4 点击: 下一张
///   - 中心区域单击: 切换顶部/底部栏可见性
///   - 中心区域双击: 旋转90度 (再次双击复原)
class ContentWidget extends ConsumerStatefulWidget {
  /// 切换顶部/底部栏可见性回调
  final VoidCallback? onToggleBars;

  /// 上一张回调
  final VoidCallback? onPrevious;

  /// 下一张回调
  final VoidCallback? onNext;

  /// 顶部排除区域高度 (不响应手势)
  final double topExcludeHeight;

  /// 底部排除区域高度 (不响应手势)
  final double bottomExcludeHeight;

  const ContentWidget({
    super.key,
    this.onToggleBars,
    this.onPrevious,
    this.onNext,
    this.topExcludeHeight = 0,
    this.bottomExcludeHeight = 0,
  });

  @override
  ConsumerState<ContentWidget> createState() => _ContentWidgetState();
}

class _ContentWidgetState extends ConsumerState<ContentWidget> {
  /// 旋转角度 (0, 1, 2, 3 表示 0°, 90°, 180°, 270°)
  int _quarterTurns = 0;

  @override
  Widget build(BuildContext context) {
    final assetsAsync = ref.watch(mediaAssetListProvider);
    final currentIndex = ref.watch(galleryCurrentIndexProvider);

    return assetsAsync.when(
      loading: () => Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
      error: (error, stack) => Container(
        color: Colors.black,
        child: Center(
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
      ),
      data: (assets) {
        if (assets.isEmpty) {
          return Container(
            color: Colors.black,
            child: const Center(
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
            ),
          );
        }

        // 索引越界检查
        if (currentIndex < 0 || currentIndex >= assets.length) {
          final safeIndex = currentIndex.clamp(0, assets.length - 1);
          // 索引越界，延迟修正并显示加载状态
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(galleryCurrentIndexProvider.notifier).update(safeIndex);
          });
          return Container(
            color: Colors.black,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }

        final currentAsset = assets[currentIndex];
        
        // 如果当前文件已删除，自动跳到下一个未删除的
        if (currentAsset.isDeleted) {
          // 检查是否还有未删除的文件
          final hasNonDeleted = assets.any((a) => !a.isDeleted);
          if (!hasNonDeleted) {
            // 所有文件都已删除，显示提示信息
            return Container(
              color: Colors.black,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete_outline, color: Colors.grey, size: 64),
                    SizedBox(height: 16),
                    Text(
                      '所有文件已删除',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(currentMediaAssetProvider.notifier).skipToNextNonDeleted();
          });
          return Container(
            color: Colors.black,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }

        // 预加载附近图片（跳过已删除的）
        _precacheNearbyImages(assets, currentIndex);

        return LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              color: Colors.black,
              child: Stack(
                children: [
                  // 主内容区 - 当前媒体
                  Positioned.fill(
                    child: _MediaItemView(
                      key: ValueKey('${currentAsset.id}_$_quarterTurns'),
                      asset: currentAsset,
                      rotationQuarterTurns: _quarterTurns,
                    ),
                  ),

                  // 顶部信息栏 (半透明覆盖)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: _TopInfoBar(
                        currentIndex: currentIndex,
                        total: assets.length,
                        asset: currentAsset,
                      ),
                    ),
                  ),

                  // 底部进度指示 (当底部栏可见时上浮)
                  Positioned(
                    bottom: widget.bottomExcludeHeight > 0 
                        ? widget.bottomExcludeHeight + 8 
                        : 8,
                    left: 16,
                    right: 16,
                    child: IgnorePointer(
                      child: _ProgressIndicator(
                        current: currentIndex + 1,
                        total: assets.length,
                      ),
                    ),
                  ),

                  Stack(
                    children: [
                      // 左侧导航按钮 - 上一张
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: constraints.maxWidth / 4,
                        child: _SimpleNavigationButton(
                          onTap: _hasPreviousNonDeleted(assets, currentIndex) ? widget.onPrevious : null,
                          icon: Icons.chevron_left,
                          alignment: Alignment.centerLeft,
                        ),
                      ),
                      // 右侧导航按钮 - 下一张
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        width: constraints.maxWidth / 4,
                        child: _SimpleNavigationButton(
                          onTap: _hasNextNonDeleted(assets, currentIndex) ? widget.onNext : null,
                          icon: Icons.chevron_right,
                          alignment: Alignment.centerRight,
                        ),
                      ),
                      // 中心区域 - 用于切换工具栏和旋转
                      Positioned(
                        left: constraints.maxWidth / 4,
                        right: constraints.maxWidth / 4,
                        top: 0,
                        bottom: 0,
                        child: _SimpleCenterZone(
                          onSingleTap: widget.onToggleBars,
                          onDoubleTap: _toggleRotation,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// 切换旋转状态 (只在 0 和 1 之间切换)
  void _toggleRotation() {
    setState(() {
      _quarterTurns = _quarterTurns == 0 ? 1 : 0;
    });
  }
  
  /// 检查是否有上一个未删除的文件
  bool _hasPreviousNonDeleted(List<MediaAsset> assets, int currentIndex) {
    for (int i = currentIndex - 1; i >= 0; i--) {
      if (!assets[i].isDeleted) return true;
    }
    return false;
  }
  
  /// 检查是否有下一个未删除的文件
  bool _hasNextNonDeleted(List<MediaAsset> assets, int currentIndex) {
    for (int i = currentIndex + 1; i < assets.length; i++) {
      if (!assets[i].isDeleted) return true;
    }
    return false;
  }

  /// 预加载附近图片 (当前位置前3个，后5个，跳过已删除)
  void _precacheNearbyImages(List<MediaAsset> assets, int currentIndex) {
    final apiClient = ref.read(apiClientManagerProvider);
    final baseUrl = apiClient.baseUrl;
    final headers = apiClient.headers;
    
    // 计算预加载范围: 前3个，后5个
    final start = (currentIndex - 3).clamp(0, assets.length - 1);
    final end = (currentIndex + 5).clamp(0, assets.length - 1);
    
    for (int i = start; i <= end; i++) {
      if (i == currentIndex) continue; // 跳过当前图片
      
      final asset = assets[i];
      // 跳过已删除的文件
      if (asset.isDeleted) continue;
      
      if (asset.isImage) {
        final imageUrl = '$baseUrl/api/gallery/${asset.id}/file';
        // 使用 CachedNetworkImageProvider 预缓存
        precacheImage(
          CachedNetworkImageProvider(imageUrl, headers: headers),
          context,
        );
      }
    }
  }
}

/// 简化的中心区域 - 处理单击和双击
class _SimpleCenterZone extends StatelessWidget {
  final VoidCallback? onSingleTap;
  final VoidCallback? onDoubleTap;

  const _SimpleCenterZone({
    this.onSingleTap,
    this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onSingleTap,
      onDoubleTap: onDoubleTap,
      child: const SizedBox.expand(),
    );
  }
}

/// 简化的导航按钮 - 用于上一张/下一张
/// TapGestureRecognizer 在检测到多指时会自动失败，不会与 ScaleGestureRecognizer 冲突
class _SimpleNavigationButton extends StatelessWidget {
  final VoidCallback? onTap;
  final IconData icon;
  final Alignment alignment;

  const _SimpleNavigationButton({
    required this.onTap,
    required this.icon,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      child: Container(
        alignment: alignment,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: AnimatedOpacity(
          opacity: onTap != null ? 0.3 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Icon(
            icon,
            color: Colors.white,
            size: 40,
          ),
        ),
      ),
    );
  }
}

/// 单个媒体项视图 (图片/视频)
class _MediaItemView extends ConsumerStatefulWidget {
  final MediaAsset asset;
  final int rotationQuarterTurns;

  const _MediaItemView({
    super.key,
    required this.asset,
    this.rotationQuarterTurns = 0,
  });

  @override
  ConsumerState<_MediaItemView> createState() => _MediaItemViewState();
}

class _MediaItemViewState extends ConsumerState<_MediaItemView> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isVideoInitialized = false;
  String? _videoError;

  @override
  void initState() {
    super.initState();
    if (widget.asset.isVideo) {
      _initVideoPlayer();
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _initVideoPlayer() async {
    try {
      final apiClient = ref.read(apiClientManagerProvider);
      final baseUrl = apiClient.baseUrl;
      final headers = apiClient.headers;
      final videoUrl = '$baseUrl/api/gallery/${widget.asset.id}/file';
      
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        httpHeaders: headers,
      );
      await _videoController!.initialize();
      
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: false,
        looping: false,
        aspectRatio: _videoController!.value.aspectRatio,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        placeholder: _buildVideoPlaceholder(),
        errorBuilder: (context, errorMessage) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 48),
              const SizedBox(height: 8),
              Text(
                '视频加载失败',
                style: TextStyle(color: Colors.grey[400]),
              ),
            ],
          ),
        ),
      );
      
      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _videoError = e.toString();
        });
      }
    }
  }

  Widget _buildVideoPlaceholder() {
    final storage = ref.read(galleryStorageProvider);
    return FutureBuilder<File?>(
      future: _getPreviewFile(storage),
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file != null) {
          return Image.file(
            file,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Icon(Icons.videocam, color: Colors.grey, size: 64),
            ),
          );
        }
        return const Center(
          child: Icon(Icons.videocam, color: Colors.grey, size: 64),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(galleryStorageProvider);
    final apiClient = ref.read(apiClientManagerProvider);
    final baseUrl = apiClient.baseUrl;
    final headers = apiClient.headers;

    // 图片类型 - 使用 CachedNetworkImage
    if (widget.asset.isImage) {
      final imageUrl = '$baseUrl/api/gallery/${widget.asset.id}/file';
      
      return _NetworkImageWithLocalPlaceholder(
        imageUrl: imageUrl,
        asset: widget.asset,
        storage: storage,
        rotationQuarterTurns: widget.rotationQuarterTurns,
        httpHeaders: headers,
      );
    }

    // 视频类型 - 使用 Chewie 播放器
    if (widget.asset.isVideo) {
      if (_videoError != null) {
        return Container(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 48),
                const SizedBox(height: 8),
                Text(
                  '视频加载失败: $_videoError',
                  style: TextStyle(color: Colors.grey[400]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }

      if (!_isVideoInitialized) {
        return Container(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildVideoPlaceholder(),
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ],
          ),
        );
      }

      return Container(
        color: Colors.black,
        child: Chewie(controller: _chewieController!),
      );
    }

    // 其他类型
    return Container(
      color: Colors.black,
      child: const Center(
        child: Icon(Icons.insert_drive_file, color: Colors.grey, size: 64),
      ),
    );
  }

  /// 获取预览文件 (优先预览图, 其次缩略图)
  Future<File?> _getPreviewFile(GalleryStorageService storage) async {
    if (widget.asset.previewPath != null) {
      final previewFile = await storage.getPreviewFile(widget.asset.previewPath!);
      if (previewFile != null) return previewFile;
    }
    if (widget.asset.thumbPath != null) {
      return await storage.getThumbFile(widget.asset.thumbPath!);
    }
    return null;
  }
}

/// 网络图片组件 - 使用本地缩略图/预览图作为占位符
class _NetworkImageWithLocalPlaceholder extends StatefulWidget {
  final String imageUrl;
  final MediaAsset asset;
  final GalleryStorageService storage;
  final int rotationQuarterTurns;
  final Map<String, String> httpHeaders;

  const _NetworkImageWithLocalPlaceholder({
    required this.imageUrl,
    required this.asset,
    required this.storage,
    this.rotationQuarterTurns = 0,
    this.httpHeaders = const {},
  });

  @override
  State<_NetworkImageWithLocalPlaceholder> createState() =>
      _NetworkImageWithLocalPlaceholderState();
}

class _NetworkImageWithLocalPlaceholderState
    extends State<_NetworkImageWithLocalPlaceholder> {
  File? _placeholderFile;
  bool _isLoading = true;
  
  // 用于手动控制缩放和平移
  final TransformationController _transformController = TransformationController();
  
  // 最小/最大缩放
  static const double _minScale = 1.0;
  static const double _maxScale = 4.0;

  @override
  void initState() {
    super.initState();
    _loadPlaceholder();
  }
  
  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _NetworkImageWithLocalPlaceholder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id) {
      _loadPlaceholder();
      // 重置变换
      _transformController.value = Matrix4.identity();
    }
    // 旋转变化时也重置变换
    if (oldWidget.rotationQuarterTurns != widget.rotationQuarterTurns) {
      _transformController.value = Matrix4.identity();
    }
  }

  Future<void> _loadPlaceholder() async {
    setState(() {
      _isLoading = true;
    });

    File? file;
    try {
      if (widget.asset.previewPath != null) {
        file = await widget.storage.getPreviewFile(widget.asset.previewPath!);
      }
      if (file == null && widget.asset.thumbPath != null) {
        file = await widget.storage.getThumbFile(widget.asset.thumbPath!);
      }
    } catch (e) {
      // 忽略错误,使用加载指示器
    }

    if (mounted) {
      setState(() {
        _placeholderFile = file;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 使用 RotatedBox + InteractiveViewer 组合
    // RotatedBox 处理布局（交换宽高）
    // InteractiveViewer 处理缩放和平移，其手势在 RotatedBox 内部，坐标系正确
    return Container(
      color: Colors.black,
      child: RotatedBox(
        quarterTurns: widget.rotationQuarterTurns,
        child: CachedNetworkImage(
          imageUrl: widget.imageUrl,
          httpHeaders: widget.httpHeaders,
          imageBuilder: (context, imageProvider) => _buildInteractiveImage(
            imageProvider,
            ValueKey('photo_${widget.asset.id}_${widget.rotationQuarterTurns}'),
          ),
          placeholder: (context, url) => _buildPlaceholderOrLoading(),
          errorWidget: (context, url, error) => _buildErrorOrPlaceholder(),
        ),
      ),
    );
  }
  
  Widget _buildInteractiveImage(ImageProvider imageProvider, Key key) {
    return InteractiveViewer(
      key: key,
      transformationController: _transformController,
      minScale: _minScale,
      maxScale: _maxScale,
      panEnabled: true,
      scaleEnabled: true,
      // 限制在边界内平移
      boundaryMargin: EdgeInsets.zero,
      constrained: true,
      child: Center(
        child: Image(
          image: imageProvider,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildPlaceholderOrLoading() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_placeholderFile != null) {
      return InteractiveViewer(
        key: ValueKey('placeholder_${widget.asset.id}_${widget.rotationQuarterTurns}'),
        minScale: _minScale,
        maxScale: _maxScale,
        boundaryMargin: EdgeInsets.zero,
        constrained: true,
        child: Center(
          child: Image.file(
            _placeholderFile!,
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    return const Center(
      child: CircularProgressIndicator(color: Colors.white),
    );
  }

  Widget _buildErrorOrPlaceholder() {
    if (_placeholderFile != null) {
      return InteractiveViewer(
        key: ValueKey('error_${widget.asset.id}_${widget.rotationQuarterTurns}'),
        minScale: _minScale,
        maxScale: _maxScale,
        boundaryMargin: EdgeInsets.zero,
        constrained: true,
        child: Center(
          child: Image.file(
            _placeholderFile!,
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    return Center(
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
    );
  }
}

/// 顶部信息栏 - 显示删除/捆绑标记
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
    // 如果没有需要显示的标记，返回空容器
    final hasMarkers = (asset?.isDeleted ?? false) || asset?.groupId != null;
    if (!hasMarkers) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
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