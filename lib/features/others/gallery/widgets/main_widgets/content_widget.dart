import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/providers/gallery_providers.dart';
import 'package:torrid/features/others/gallery/widgets/main_widgets/media_item_view.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

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
      loading: () => _buildLoadingState(),
      error: (error, stack) => _buildErrorState(error),
      data: (assets) => _buildDataState(assets, currentIndex),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Container(
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
    );
  }

  Widget _buildDataState(List<MediaAsset> assets, int currentIndex) {
    if (assets.isEmpty) {
      return _buildEmptyState();
    }

    // 索引越界检查
    if (currentIndex < 0 || currentIndex >= assets.length) {
      final safeIndex = currentIndex.clamp(0, assets.length - 1);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(galleryCurrentIndexProvider.notifier).update(safeIndex);
      });
      return _buildLoadingState();
    }

    final currentAsset = assets[currentIndex];

    // 如果当前文件已删除，自动跳到下一个未删除的
    if (currentAsset.isDeleted) {
      return _handleDeletedAsset(assets);
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
                child: MediaItemView(
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

              // 手势操作层 - 根据媒体类型选择不同交互方式
              if (currentAsset.isVideo)
                _VideoControlOverlay(
                  onPrevious: _hasPreviousNonDeleted(assets, currentIndex)
                      ? widget.onPrevious
                      : null,
                  onNext: _hasNextNonDeleted(assets, currentIndex)
                      ? widget.onNext
                      : null,
                  onRotate: _toggleRotation,
                  onToggleBars: widget.onToggleBars,
                )
              else
                _buildGestureLayer(assets, currentIndex, constraints),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
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

  Widget _handleDeletedAsset(List<MediaAsset> assets) {
    final hasNonDeleted = assets.any((a) => !a.isDeleted);
    if (!hasNonDeleted) {
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
    return _buildLoadingState();
  }

  Widget _buildGestureLayer(
    List<MediaAsset> assets,
    int currentIndex,
    BoxConstraints constraints,
  ) {
    return Stack(
      children: [
        // 左侧导航按钮 - 上一张
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: constraints.maxWidth / 4,
          child: _SimpleNavigationButton(
            onTap: _hasPreviousNonDeleted(assets, currentIndex)
                ? widget.onPrevious
                : null,
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
            onTap: _hasNextNonDeleted(assets, currentIndex)
                ? widget.onNext
                : null,
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

    final start = (currentIndex - 3).clamp(0, assets.length - 1);
    final end = (currentIndex + 5).clamp(0, assets.length - 1);

    for (int i = start; i <= end; i++) {
      if (i == currentIndex) continue;

      final asset = assets[i];
      if (asset.isDeleted) continue;

      if (asset.isImage) {
        final imageUrl = '$baseUrl/api/gallery/${asset.id}/file';
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
    final hasMarkers = (asset?.isDeleted ?? false) || asset?.groupId != null;
    if (!hasMarkers) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
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
        Text(
          '$current / $total',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
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

/// 视频控制覆盖层 - 使用浮动按钮不阻挡视频播放器控制
class _VideoControlOverlay extends StatelessWidget {
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onRotate;
  final VoidCallback? onToggleBars;

  const _VideoControlOverlay({
    this.onPrevious,
    this.onNext,
    this.onRotate,
    this.onToggleBars,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 左下角 - 上一个按钮
        Positioned(
          left: 12,
          bottom: 60, // 避开底部进度条
          child: _FloatingControlButton(
            icon: Icons.skip_previous_rounded,
            onTap: onPrevious,
            tooltip: '上一个',
          ),
        ),
        // 右下角 - 下一个按钮
        Positioned(
          right: 12,
          bottom: 60,
          child: _FloatingControlButton(
            icon: Icons.skip_next_rounded,
            onTap: onNext,
            tooltip: '下一个',
          ),
        ),
        // 右上角 - 旋转按钮
        Positioned(
          right: 12,
          top: 60, // 避开顶部安全区
          child: _FloatingControlButton(
            icon: Icons.rotate_right_rounded,
            onTap: onRotate,
            tooltip: '旋转',
          ),
        ),
        // 左上角 - 切换工具栏按钮
        Positioned(
          left: 12,
          top: 60,
          child: _FloatingControlButton(
            icon: Icons.visibility_rounded,
            onTap: onToggleBars,
            tooltip: '显示/隐藏工具栏',
          ),
        ),
      ],
    );
  }
}

/// 浮动控制按钮 - 半透明圆形按钮
class _FloatingControlButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;

  const _FloatingControlButton({
    required this.icon,
    this.onTap,
    this.tooltip = '',
  });

  @override
  State<_FloatingControlButton> createState() => _FloatingControlButtonState();
}

class _FloatingControlButtonState extends State<_FloatingControlButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onTap != null;
    
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTapDown: isEnabled ? (_) => setState(() => _isPressed = true) : null,
        onTapUp: isEnabled ? (_) => setState(() => _isPressed = false) : null,
        onTapCancel: isEnabled ? () => setState(() => _isPressed = false) : null,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _isPressed
                ? Colors.white.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: isEnabled ? 0.5 : 0.2),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: isEnabled ? 0.3 : 0.1),
              width: 1,
            ),
          ),
          child: Icon(
            widget.icon,
            color: Colors.white.withValues(alpha: isEnabled ? 0.9 : 0.3),
            size: 24,
          ),
        ),
      ),
    );
  }
}
