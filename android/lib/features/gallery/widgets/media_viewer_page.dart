import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';
import 'package:torrid/app/theme/theme_book.dart';
import 'package:torrid/features/gallery/models/media_asset.dart';
import 'package:torrid/features/gallery/models/media_orientation.dart';
import 'package:torrid/features/gallery/providers/settings_providers.dart';
import 'package:torrid/features/gallery/services/gallery_api_service.dart';
import 'package:torrid/features/gallery/widgets/main_widgets/gallery_video.dart';
import 'package:torrid/features/gallery/widgets/main_widgets/network_image_widget.dart';
import 'package:torrid/features/gallery/services/media_share_service.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

/// 全屏媒体查看页：图片可缩放平移、视频可直接播放，左右滑动切换上一个/下一个。
///
/// [assets] 是调用方列表的一份快照：翻页不会触发新的服务端请求，也就不会因为
/// 列表在背后刷新而让当前查看的媒体跳位。
class MediaViewerPage extends ConsumerStatefulWidget {
  const MediaViewerPage({
    super.key,
    required this.assets,
    this.initialIndex = 0,
    this.actions,
    this.subtitleBuilder,
    this.review = false,
  });

  final List<MediaAsset> assets;
  final int initialIndex;
  final bool review;

  /// 右上角操作按钮，按当前媒体构建。
  final List<Widget> Function(BuildContext context, MediaAsset asset)? actions;

  /// 标题下方的一行说明（如相关度、命中来源）；返回 null 表示不显示。
  final String? Function(MediaAsset asset)? subtitleBuilder;

  @override
  ConsumerState<MediaViewerPage> createState() => _MediaViewerPageState();
}

class _MediaViewerPageState extends ConsumerState<MediaViewerPage> {
  late final PageController _controller;
  late int _index;

  /// 点击图片可临时隐藏顶栏，得到无遮挡的观看区域。
  bool _chromeVisible = true;
  int _quarterTurns = 0;
  bool _manuallyRotated = false;
  CancelToken? _shareCancel;
  double? _shareProgress;

  @override
  void initState() {
    super.initState();
    _index = widget.assets.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.assets.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    _shareCancel?.cancel();
    super.dispose();
  }

  void _toggleChrome() => setState(() => _chromeVisible = !_chromeVisible);

  void _rotate() {
    setState(() {
      _quarterTurns = _quarterTurns == 0 ? 1 : 0;
      _manuallyRotated = true;
    });
  }

  void _fitOrientation(String id, double ratio) {
    if (!mounted ||
        widget.assets[_index].id != id ||
        _manuallyRotated ||
        !ref.read(galleryBrowseSettingsProvider).autoOrientation) {
      return;
    }
    final turns = mediaOrientationTurns(ratio, _quarterTurns);
    if (turns != _quarterTurns) setState(() => _quarterTurns = turns);
  }

  Widget _reviewBar(String? detail) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (detail != null && detail.isNotEmpty)
            TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('推荐理由'),
                  content: Text(detail),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('关闭'),
                    ),
                  ],
                ),
              ),
              child: Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          IconButtonTheme(
            data: IconButtonThemeData(
              style: IconButton.styleFrom(
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white30,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  tooltip: '上一项',
                  onPressed: _index > 0
                      ? () => _controller.jumpToPage(_index - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  tooltip: '旋转方向',
                  onPressed: _rotate,
                  icon: const Icon(Icons.rotate_right_rounded),
                ),
                IconButton(
                  tooltip: '下一项',
                  onPressed: _index + 1 < widget.assets.length
                      ? () => _controller.jumpToPage(_index + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.assets.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('没有可查看的媒体', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    final api = ref.watch(apiClientManagerProvider);
    final asset = widget.assets[_index];
    final subtitle = widget.subtitleBuilder?.call(asset);
    final meta = <String>[
      if (widget.assets.length > 1) '${_index + 1}/${widget.assets.length}',
      _formatDate(asset.capturedAt),
      if (!widget.review && subtitle != null && subtitle.isNotEmpty) subtitle,
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: !widget.review && !asset.isVideo,
      bottomNavigationBar: widget.review && _chromeVisible
          ? _reviewBar(subtitle)
          : null,
      appBar: _chromeVisible
          ? AppBar(
              backgroundColor: AppTheme.mediaOverlay,
              foregroundColor: Colors.white,
              elevation: 0,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _fileName(asset.filePath),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                  Text(
                    meta.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: _shareCancel == null ? '分享' : '取消准备分享',
                  onPressed: () => _shareCancel == null
                      ? _share(asset)
                      : _shareCancel?.cancel(),
                  icon: _shareCancel == null
                      ? const Icon(Icons.share_outlined)
                      : SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            value: _shareProgress,
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                ),
                ...?widget.actions?.call(context, asset),
              ],
            )
          : null,
      body: PhotoViewGestureDetectorScope(
        // 交给 PhotoView：未放大时让出水平拖动给 PageView，放大后才拦截
        axis: Axis.horizontal,
        child: PageView.builder(
          controller: _controller,
          itemCount: widget.assets.length,
          onPageChanged: (index) => setState(() {
            _index = index;
            _manuallyRotated = false;
            if (widget.review && widget.assets[index].isVideo) {
              _chromeVisible = true;
            }
          }),
          itemBuilder: (context, index) {
            final item = widget.assets[index];
            if (widget.review && index != _index) {
              return const SizedBox.expand();
            }
            if (item.isVideo) {
              // 只为当前页创建播放器：PageView 会预建相邻页，
              // 若每页都建控制器就会出现多路视频同时解码
              if (index != _index) {
                return const Center(
                  child: Icon(
                    Icons.play_circle_outline,
                    color: Colors.white24,
                    size: 64,
                  ),
                );
              }
              return SafeArea(
                child: GalleryVideo(
                  key: ValueKey('viewer_video_${item.id}'),
                  asset: item,
                  autoPlay: true,
                  quarterTurns: widget.review ? _quarterTurns : 0,
                  onAspectRatio: widget.review
                      ? (ratio) => _fitOrientation(item.id, ratio)
                      : null,
                ),
              );
            }
            if (widget.review) {
              return GestureDetector(
                key: ValueKey('review_image_${item.id}'),
                onTap: _toggleChrome,
                onDoubleTap: _rotate,
                child: NetworkImageWidget(
                  asset: item.copyWith(clearEditParams: true),
                  imageUrl: galleryMediaUrl(api.baseUrl, item),
                  httpHeaders: api.headers,
                  rotationQuarterTurns: _quarterTurns,
                  maxDecodeEdge: 4096,
                  onAspectRatio: (ratio) => _fitOrientation(item.id, ratio),
                ),
              );
            }
            return PhotoView(
              key: ValueKey('viewer_image_${item.id}'),
              imageProvider: CachedNetworkImageProvider(
                galleryMediaUrl(api.baseUrl, item),
                headers: api.headers,
              ),
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              initialScale: PhotoViewComputedScale.contained,
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.contained * 5,
              onTapUp: (_, _, _) => _toggleChrome(),
              loadingBuilder: (context, progress) => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              errorBuilder: (context, error, stack) => const Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white38,
                  size: 56,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _share(MediaAsset asset) async {
    final client = ref.read(apiClientManagerProvider);
    final cancel = CancelToken();
    setState(() {
      _shareCancel = cancel;
      _shareProgress = null;
    });
    try {
      await shareMedia(
        client,
        asset,
        cancelToken: cancel,
        onProgress: (received, total) {
          if (mounted && !cancel.isCancelled) {
            setState(
              () => _shareProgress = total > 0 ? received / total : null,
            );
          }
        },
      );
    } catch (error) {
      if (mounted && !cancel.isCancelled) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('分享失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _shareCancel = null);
    }
  }
}

/// 取路径最后一段作为文件名（兼容两种分隔符）。
String _fileName(String path) {
  final segments = path.split(RegExp(r'[/\\]'));
  return segments.isEmpty ? path : segments.last;
}

String _formatDate(DateTime time) {
  final local = time.toLocal();
  String pad(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${pad(local.month)}-${pad(local.day)} '
      '${pad(local.hour)}:${pad(local.minute)}';
}
