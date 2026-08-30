import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/services/gallery_storage_service.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';
import 'package:video_player/video_player.dart';

/// 视频播放器组件（自实现播放控制，不依赖 chewie）
///
/// 功能：播放/暂停、后退/快进 10 秒、**可拖动进度条**（松手按实际松手位置
/// 精确落点，修复了 chewie 内置进度条"快速拖动落点偏短（只能到 ~80%）"的
/// 问题）、时间显示、3 秒无操作自动隐藏控制条（点按视频显示/隐藏）。
///
/// 外层结构保持不变：网络视频播放、旋转、本地预览图占位、错误态。
class VideoPlayerWidget extends ConsumerStatefulWidget {
  final MediaAsset asset;
  final int rotationQuarterTurns;
  final GalleryStorageService storage;

  const VideoPlayerWidget({
    super.key,
    required this.asset,
    required this.storage,
    this.rotationQuarterTurns = 0,
  });

  @override
  ConsumerState<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends ConsumerState<VideoPlayerWidget> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  String? _videoError;
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    // 使用 addPostFrameCallback 确保 context 和 ref 可用
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initVideoPlayer();
    });
  }

  @override
  void didUpdateWidget(covariant VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果 asset 变化，重新初始化视频控制器
    if (oldWidget.asset.id != widget.asset.id) {
      _disposeControllers();
      _initVideoPlayer();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    _videoController?.dispose();
    _videoController = null;
    _isVideoInitialized = false;
    _isInitializing = false; // 复位，否则 asset 切换后无法重新初始化
    _videoError = null;
  }

  Future<void> _initVideoPlayer() async {
    if (_isInitializing || !mounted) return;
    _isInitializing = true;
    // 记录本次初始化的目标 asset，防止快速切换时旧初始化结果覆盖新 asset
    final targetAssetId = widget.asset.id;

    try {
      final apiClient = ref.read(apiClientManagerProvider);
      final baseUrl = apiClient.baseUrl;
      final headers = apiClient.headers;
      final videoUrl = '$baseUrl/API/gallery/${widget.asset.id}/file';

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        httpHeaders: headers,
      );

      await controller.initialize();

      if (!mounted || widget.asset.id != targetAssetId) {
        controller.dispose();
        return;
      }

      _videoController = controller;

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
      }
    } catch (e) {
      if (mounted && widget.asset.id == targetAssetId) {
        setState(() {
          _videoError = e.toString();
        });
      }
    } finally {
      _isInitializing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 错误状态
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

    // 加载中状态 - 显示预览图和加载指示器
    if (!_isVideoInitialized) {
      return Container(
        color: Colors.black,
        child: RotatedBox(
          quarterTurns: widget.rotationQuarterTurns,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _VideoPlaceholder(
                asset: widget.asset,
                storage: widget.storage,
              ),
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    // 已初始化 - 显示播放器（应用旋转）
    return Container(
      color: Colors.black,
      child: RotatedBox(
        quarterTurns: widget.rotationQuarterTurns,
        child: Center(
          child: AspectRatio(
            aspectRatio: _videoController!.value.aspectRatio,
            child: _PlayerSurface(controller: _videoController!),
          ),
        ),
      ),
    );
  }
}

/// 播放画面 + 自实现控制条（进度条/播放暂停/±10秒/时间/自动隐藏）
class _PlayerSurface extends StatefulWidget {
  final VideoPlayerController controller;

  const _PlayerSurface({required this.controller});

  @override
  State<_PlayerSurface> createState() => _PlayerSurfaceState();
}

class _PlayerSurfaceState extends State<_PlayerSurface> {
  VideoPlayerController get _vc => widget.controller;

  bool _controlsVisible = true;
  bool _dragging = false;
  double _dragFraction = 0;
  bool _wasPlayingBeforeDrag = false;
  Timer? _hideTimer;

  final GlobalKey _barKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _vc.addListener(_onValueChanged);
    _restartHideTimer();
  }

  @override
  void dispose() {
    _vc.removeListener(_onValueChanged);
    _hideTimer?.cancel();
    super.dispose();
  }

  void _onValueChanged() {
    if (mounted) setState(() {});
  }

  // ============ 显示/隐藏 ============

  void _restartHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_dragging) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    _restartHideTimer();
    setState(() => _controlsVisible = !_controlsVisible);
  }

  void _showControls() {
    _restartHideTimer();
    if (!_controlsVisible) setState(() => _controlsVisible = true);
  }

  // ============ 播放控制 ============

  Future<void> _togglePlay() async {
    if (!_vc.value.isInitialized) return;
    _restartHideTimer();
    try {
      if (_vc.value.isPlaying) {
        await _vc.pause();
      } else {
        await _vc.play();
      }
    } catch (_) {}
  }

  /// 相对当前位置快进/后退 10 秒（seekTo 内部会 clamp 到时长范围内）
  void _skipRelative(Duration delta) {
    if (!_vc.value.isInitialized) return;
    _restartHideTimer();
    var target = _vc.value.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    _vc.seekTo(target);
  }

  // ============ 进度条 ============

  /// 按 0~1 比例 seek，边界收敛后交给播放器（其内部再 clamp 到 duration）
  void _seekToFraction(double fraction) {
    if (!_vc.value.isInitialized) return;
    final duration = _vc.value.duration;
    // 时长异常（流媒体尚未解析出时长等）时放弃 seek
    if (duration.inMilliseconds <= 0) return;
    final f = fraction.clamp(0.0, 1.0);
    _vc.seekTo(Duration(milliseconds: (duration.inMilliseconds * f).round()));
  }

  Widget _buildProgressBar() {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        // 点按即跳转（精确落点）
        onTapDown: (d) {
          _showControls();
          _seekToFraction(d.localPosition.dx / width);
        },
        // 拖动开始：暂停播放，避免 seek 与 play 竞争
        onHorizontalDragStart: (d) {
          _showControls();
          if (!_vc.value.isInitialized) return;
          setState(() {
            _dragging = true;
            _dragFraction = (d.localPosition.dx / width).clamp(0.0, 1.0);
          });
          _wasPlayingBeforeDrag = _vc.value.isPlaying;
          if (_wasPlayingBeforeDrag) {
            _vc.pause();
          }
          _seekToFraction(_dragFraction);
        },
        // 拖动中：进度条跟随手指
        onHorizontalDragUpdate: (d) {
          if (!_dragging) return;
          setState(() {
            _dragFraction = (d.localPosition.dx / width).clamp(0.0, 1.0);
          });
        },
        // 拖动结束：按**实际松手位置**精确 seek（避免快速拖动落点偏短），
        // 然后恢复之前的播放状态
        onHorizontalDragEnd: (d) {
          if (!_dragging) return;
          _dragging = false;
          final box = _barKey.currentContext?.findRenderObject() as RenderBox?;
          if (box != null && box.attached) {
            final local = box.globalToLocal(d.globalPosition);
            _seekToFraction(local.dx / box.size.width);
          } else {
            _seekToFraction(_dragFraction);
          }
          if (_wasPlayingBeforeDrag) {
            _vc.play();
          }
          _restartHideTimer();
          if (mounted) setState(() {});
        },
        onHorizontalDragCancel: () {
          _dragging = false;
          if (_wasPlayingBeforeDrag) {
            _vc.play();
          }
          if (mounted) setState(() {});
        },
        child: SizedBox(
          key: _barKey,
          height: 32,
          child: _buildBarContent(width),
        ),
      );
    });
  }

  Widget _buildBarContent(double width) {
    final value = _vc.value;
    final durMs = value.duration.inMilliseconds;

    // 拖动中显示手指位置，否则显示实际播放位置
    final displayMs =
        _dragging ? durMs * _dragFraction : value.position.inMilliseconds;
    final played =
        durMs <= 0 ? 0.0 : (displayMs / durMs).clamp(0.0, 1.0).toDouble();

    // 缓冲进度（取最大缓冲终点）
    double buffered = 0;
    if (durMs > 0) {
      for (final range in value.buffered) {
        final end = range.end.inMilliseconds / durMs;
        if (end > buffered) buffered = end;
      }
    }
    buffered = buffered.clamp(0.0, 1.0);

    const trackH = 3.0;
    const handleR = 7.0;
    final barW = width * played;
    // 手柄中心保持在轨道范围内，避免被裁剪（已播条宽度仍用真实比例）
    final cx = barW.clamp(handleR, width - handleR);

    return Stack(
      alignment: Alignment.center,
      children: [
        // 底轨
        Container(
          height: trackH,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        // 缓冲
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: width * buffered,
            height: trackH,
            decoration: BoxDecoration(
              color: Colors.white38,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        // 已播
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: barW,
            height: trackH,
            decoration: BoxDecoration(
              color: Colors.blueAccent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        // 手柄（垂直居中）
        Positioned(
          left: cx - handleR,
          top: 0,
          bottom: 0,
          child: Center(
            child: Container(
              width: handleR * 2,
              height: handleR * 2,
              decoration: BoxDecoration(
                color: Colors.blueAccent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============ 整体布局 ============

  @override
  Widget build(BuildContext context) {
    final value = _vc.value;
    final duration = value.duration;
    final position = _dragging
        ? Duration(milliseconds: (duration.inMilliseconds * _dragFraction).round())
        : value.position;

    return Stack(
      children: [
        // 视频画面
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleControls,
            child: VideoPlayer(_vc),
          ),
        ),
        // 底部控制条（可隐藏）
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            ignoring: !_controlsVisible,
            child: AnimatedOpacity(
              opacity: _controlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
                padding: const EdgeInsets.only(bottom: 2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildProgressBar(),
                    Row(
                      children: [
                        _ControlButton(
                          icon: Icons.replay_10,
                          tooltip: '后退10秒',
                          onPressed: () =>
                              _skipRelative(const Duration(seconds: -10)),
                        ),
                        _ControlButton(
                          icon: value.isPlaying
                              ? Icons.pause
                              : Icons.play_arrow,
                          tooltip: value.isPlaying ? '暂停' : '播放',
                          onPressed: _togglePlay,
                        ),
                        _ControlButton(
                          icon: Icons.forward_10,
                          tooltip: '快进10秒',
                          onPressed: () =>
                              _skipRelative(const Duration(seconds: 10)),
                        ),
                        Text(
                          '${_fmt(position)} / ${_fmt(duration)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

/// 控制条小图标按钮（紧凑尺寸）
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _ControlButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: Colors.white, size: 26),
      onPressed: onPressed,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      padding: EdgeInsets.zero,
    );
  }
}

/// 视频占位图组件
class _VideoPlaceholder extends StatelessWidget {
  final MediaAsset asset;
  final GalleryStorageService storage;

  const _VideoPlaceholder({
    required this.asset,
    required this.storage,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: _getPreviewFile(),
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

  Future<File?> _getPreviewFile() async {
    if (asset.previewPath != null) {
      final previewFile = await storage.getPreviewFile(asset.previewPath!);
      if (previewFile != null) return previewFile;
    }
    if (asset.thumbPath != null) {
      return await storage.getThumbFile(asset.thumbPath!);
    }
    return null;
  }
}
