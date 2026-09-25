import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/widgets/main_widgets/video_player_widget.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

/// 全屏媒体查看页：图片可缩放平移、视频可直接播放，左右滑动切换上一个/下一个。
///
/// 相册(immich)与智能相册共用同一套"看单个媒体"的体验。两页的数据来源与可执行
/// 操作不同，各自通过 [actions] 注入入口（人工标签管理 / 以图搜图），本页只负责呈现。
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
  });

  final List<MediaAsset> assets;
  final int initialIndex;

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
    super.dispose();
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
      if (subtitle != null && subtitle.isNotEmpty) subtitle,
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _chromeVisible
          ? AppBar(
              backgroundColor: Colors.black54,
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
              actions: widget.actions?.call(context, asset),
            )
          : null,
      body: PhotoViewGestureDetectorScope(
        // 交给 PhotoView：未放大时让出水平拖动给 PageView，放大后才拦截
        axis: Axis.horizontal,
        child: PageView.builder(
          controller: _controller,
          itemCount: widget.assets.length,
          onPageChanged: (index) => setState(() => _index = index),
          itemBuilder: (context, index) {
            final item = widget.assets[index];
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
              return VideoPlayerWidget(
                key: ValueKey('viewer_video_${item.id}'),
                asset: item,
                autoPlay: true,
              );
            }
            return PhotoView(
              key: ValueKey('viewer_image_${item.id}'),
              imageProvider: CachedNetworkImageProvider(
                '${api.baseUrl}/API/gallery/${item.id}/file',
                headers: api.headers,
              ),
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              initialScale: PhotoViewComputedScale.contained,
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.contained * 5,
              onTapUp: (_, __, ___) =>
                  setState(() => _chromeVisible = !_chromeVisible),
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
