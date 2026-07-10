import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/providers/gallery_providers.dart';
import 'package:torrid/features/others/gallery/widgets/main_widgets/media_item_view.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

/// 媒体内容展示组件 — 纯渲染，不管理交互状态。
///
/// 职责：
/// - 根据 [rotationQuarterTurns] 和当前 asset 渲染 [MediaItemView]
/// - 在图片模式下提供左右 1/4 点击切图 + 中心单击/双击手势
/// - 在视频模式下提供浮动控制按钮
/// - 预加载附近图片网络资源
///
/// 所有交互回调（上一张/下一张/切换工具栏/旋转）由父级 [GalleryPage] 提供。
class ContentWidget extends ConsumerStatefulWidget {
  final int rotationQuarterTurns;
  final VoidCallback? onToggleBars;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onRotate;
  final double topExcludeHeight;
  final double bottomExcludeHeight;

  const ContentWidget({
    super.key,
    this.rotationQuarterTurns = 0,
    this.onToggleBars,
    this.onPrevious,
    this.onNext,
    this.onRotate,
    this.topExcludeHeight = 0,
    this.bottomExcludeHeight = 0,
  });

  @override
  ConsumerState<ContentWidget> createState() => _ContentWidgetState();
}

class _ContentWidgetState extends ConsumerState<ContentWidget> {
  final Set<String> _precachedIds = {};
  int? _lastPrecacheIndex;

  @override
  Widget build(BuildContext context) {
    final assetsAsync = ref.watch(mediaAssetListProvider);
    final currentIndex = ref.watch(galleryCurrentIndexProvider);

    return assetsAsync.when(
      loading: () => _buildCentered(const CircularProgressIndicator(color: Colors.white)),
      error: (e, _) => _buildError(e),
      data: (assets) => _buildData(assets, currentIndex),
    );
  }

  // ---- 静态状态 ----

  Widget _buildCentered(Widget child) =>
      Container(color: Colors.black, child: Center(child: child));

  Widget _buildError(Object error) => Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text('加载失败: $error',
                  style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(mediaAssetListProvider),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );

  // ---- 数据状态 ----

  Widget _buildData(List<MediaAsset> assets, int currentIndex) {
    if (assets.isEmpty) {
      return _buildCentered(const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.photo_library_outlined, color: Colors.grey, size: 64),
          SizedBox(height: 16),
          Text('暂无媒体文件\n请在设置中下载',
              style: TextStyle(color: Colors.grey, fontSize: 16), textAlign: TextAlign.center),
        ],
      ));
    }

    // 索引越界保护
    if (currentIndex < 0 || currentIndex >= assets.length) {
      final safe = currentIndex.clamp(0, assets.length - 1);
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => ref.read(galleryCurrentIndexProvider.notifier).update(safe));
      return _buildCentered(const CircularProgressIndicator(color: Colors.white));
    }

    final currentAsset = assets[currentIndex];

    // 已删除 → 自动跳到未删除
    if (currentAsset.isDeleted) {
      final hasLive = assets.any((a) => !a.isDeleted);
      if (!hasLive) {
        return _buildCentered(const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, color: Colors.grey, size: 64),
            SizedBox(height: 16),
            Text('所有文件已删除',
                style: TextStyle(color: Colors.grey, fontSize: 16), textAlign: TextAlign.center),
          ],
        ));
      }
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => ref.read(currentMediaAssetProvider.notifier).skipToNextNonDeleted());
      return _buildCentered(const CircularProgressIndicator(color: Colors.white));
    }

    // 预加载附近图片
    if (_lastPrecacheIndex != currentIndex) {
      _lastPrecacheIndex = currentIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _precache(assets, currentIndex);
      });
    }

    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // 主内容
          Positioned.fill(
            child: MediaItemView(
              key: ValueKey('${currentAsset.id}_${widget.rotationQuarterTurns}'),
              asset: currentAsset,
              rotationQuarterTurns: widget.rotationQuarterTurns,
            ),
          ),
          // 底部进度
          Positioned(
            bottom: widget.bottomExcludeHeight > 0 ? widget.bottomExcludeHeight + 8 : 8,
            left: 16,
            right: 16,
            child: IgnorePointer(
              child: _ProgressBar(current: currentIndex + 1, total: assets.length),
            ),
          ),
          // 手势/控制层
          Positioned.fill(
            child: currentAsset.isVideo
                ? _buildVideoControls(assets, currentIndex)
                : _buildImageGestures(assets, currentIndex),
          ),
        ],
      ),
    );
  }

  // ---- 图片手势 ----

  Widget _buildImageGestures(List<MediaAsset> assets, int currentIndex) {
    final hasPrev = _hasLiveBefore(assets, currentIndex);
    final hasNext = _hasLiveAfter(assets, currentIndex);

    return LayoutBuilder(builder: (_, c) {
      final qw = c.maxWidth / 4;
      return Stack(
        children: [
          // 左 1/4
          Positioned(
            left: 0, top: 0, bottom: 0, width: qw,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: hasPrev ? widget.onPrevious : null,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: AnimatedOpacity(
                    opacity: hasPrev ? 0.3 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.chevron_left, color: Colors.white, size: 40),
                  ),
                ),
              ),
            ),
          ),
          // 右 1/4
          Positioned(
            right: 0, top: 0, bottom: 0, width: qw,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: hasNext ? widget.onNext : null,
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: AnimatedOpacity(
                    opacity: hasNext ? 0.3 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.chevron_right, color: Colors.white, size: 40),
                  ),
                ),
              ),
            ),
          ),
          // 中心 — 单击切换工具栏 / 双击旋转
          Positioned(
            left: qw, right: qw, top: 0, bottom: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: widget.onToggleBars,
              onDoubleTap: widget.onRotate,
              child: const SizedBox.expand(),
            ),
          ),
        ],
      );
    });
  }

  // ---- 视频浮动控制 ----

  Widget _buildVideoControls(List<MediaAsset> assets, int currentIndex) {
    final hasPrev = _hasLiveBefore(assets, currentIndex);
    final hasNext = _hasLiveAfter(assets, currentIndex);

    return Stack(
      children: [
        Positioned(left: 12, bottom: 60,
          child: _FloatingBtn(icon: Icons.skip_previous_rounded, tooltip: '上一个',
              enabled: hasPrev, onTap: widget.onPrevious)),
        Positioned(right: 12, bottom: 60,
          child: _FloatingBtn(icon: Icons.skip_next_rounded, tooltip: '下一个',
              enabled: hasNext, onTap: widget.onNext)),
        Positioned(right: 12, top: 60,
          child: _FloatingBtn(icon: Icons.rotate_right_rounded, tooltip: '旋转',
              enabled: true, onTap: widget.onRotate)),
        Positioned(left: 12, top: 60,
          child: _FloatingBtn(icon: Icons.visibility_rounded, tooltip: '显示/隐藏工具栏',
              enabled: true, onTap: widget.onToggleBars)),
      ],
    );
  }

  // ---- 辅助 ----

  bool _hasLiveBefore(List<MediaAsset> assets, int idx) {
    for (int i = idx - 1; i >= 0; i--) {
      if (!assets[i].isDeleted) return true;
    }
    return false;
  }

  bool _hasLiveAfter(List<MediaAsset> assets, int idx) {
    for (int i = idx + 1; i < assets.length; i++) {
      if (!assets[i].isDeleted) return true;
    }
    return false;
  }

  void _precache(List<MediaAsset> assets, int currentIndex) {
    if (!mounted) return;
    final api = ref.read(apiClientManagerProvider);
    final base = api.baseUrl;
    final hdrs = api.headers;

    const before = 3, after = 5;
    final targets = <int>[];
    for (int i = currentIndex - 1, c = 0; i >= 0 && c < before; i--) {
      if (!assets[i].isDeleted) { targets.add(i); c++; }
    }
    for (int i = currentIndex + 1, c = 0; i < assets.length && c < after; i++) {
      if (!assets[i].isDeleted) { targets.add(i); c++; }
    }

    final activeIds = targets.map((i) => assets[i].id).toSet();
    _precachedIds.removeWhere((id) => !activeIds.contains(id));

    for (final i in targets) {
      final a = assets[i];
      if (_precachedIds.contains(a.id)) continue;
      _precachedIds.add(a.id);
      if (a.isImage) {
        precacheImage(
          CachedNetworkImageProvider('$base/API/gallery/${a.id}/file', headers: hdrs),
          context,
        ).catchError((_) => _precachedIds.remove(a.id));
      }
    }
  }
}

// ---- 私有小组件 ----

class _ProgressBar extends StatelessWidget {
  final int current, total;
  const _ProgressBar({required this.current, required this.total});

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$current / $total',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
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

class _FloatingBtn extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback? onTap;
  const _FloatingBtn({required this.icon, this.tooltip = '', this.enabled = true, this.onTap});

  @override
  State<_FloatingBtn> createState() => _FloatingBtnState();
}

class _FloatingBtnState extends State<_FloatingBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final ok = widget.enabled && widget.onTap != null;
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTapDown: ok ? (_) => setState(() => _pressed = true) : null,
        onTapUp: ok ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: ok ? () => setState(() => _pressed = false) : null,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: _pressed
                ? Colors.white.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: ok ? 0.5 : 0.2),
            shape: BoxShape.circle,
            border: Border.all(
                color: Colors.white.withValues(alpha: ok ? 0.3 : 0.1), width: 1),
          ),
          child: Icon(widget.icon,
              color: Colors.white.withValues(alpha: ok ? 0.9 : 0.3), size: 24),
        ),
      ),
    );
  }
}
