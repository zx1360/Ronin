import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:torrid/core/services/debug/logging_service.dart';
import 'package:video_player/video_player.dart';

class MediaVideoPlayer extends StatefulWidget {
  const MediaVideoPlayer({
    super.key,
    required this.uri,
    this.headers = const {},
    this.autoPlay = false,
    this.looping = false,
    this.active = true,
    this.quarterTurns = 0,
    this.placeholder,
    this.onAspectRatio,
    this.allowFullscreen = false,
    this.openInBrowser,
  });

  final Uri uri;
  final Map<String, String> headers;
  final bool autoPlay;
  final bool looping;
  final bool active;
  final int quarterTurns;
  final Widget? placeholder;
  final ValueChanged<double>? onAspectRatio;
  final bool allowFullscreen;
  final VoidCallback? openInBrowser;

  @override
  State<MediaVideoPlayer> createState() => _MediaVideoPlayerState();
}

class _MediaVideoPlayerState extends State<MediaVideoPlayer>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  Timer? _initializationTimeout;
  String? _initializationError;
  bool _foreground = true;
  bool _routeCurrent = true;
  MaterialPageRoute<bool>? _fullscreenRoute;
  bool _wantsPlayback = false;
  bool _scrubbing = false;

  bool get _shouldPlay =>
      _foreground &&
      widget.active &&
      (_routeCurrent || _fullscreenRoute != null) &&
      _wantsPlayback &&
      !_scrubbing;

  @override
  void initState() {
    super.initState();
    final binding = WidgetsBinding.instance;
    _foreground =
        binding.lifecycleState == null ||
        binding.lifecycleState == AppLifecycleState.resumed;
    binding.addObserver(this);
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeCurrent = ModalRoute.isCurrentOf(context) ?? true;
    scheduleMicrotask(_syncPlayback);
  }

  @override
  void didUpdateWidget(covariant MediaVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.uri != oldWidget.uri ||
        !mapEquals(widget.headers, oldWidget.headers)) {
      _load();
    } else if (widget.active != oldWidget.active) {
      scheduleMicrotask(_syncPlayback);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncPlayback();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _closeFullscreen();
    _release();
    super.dispose();
  }

  void _release() {
    _initializationTimeout?.cancel();
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      controller.removeListener(_onVideoChanged);
      unawaited(
        controller.dispose().catchError((Object error) {
          AppLogger().warning('释放视频播放器失败：$error');
        }),
      );
    }
  }

  void _load() {
    _closeFullscreen();
    _release();
    _initializationError = null;
    _wantsPlayback = widget.autoPlay;
    _scrubbing = false;
    final uri = widget.uri;
    if (!uri.hasAuthority || (uri.scheme != 'http' && uri.scheme != 'https')) {
      _initializationError = '视频地址无效，请检查连接设置';
      return;
    }

    final controller = VideoPlayerController.networkUrl(
      uri,
      httpHeaders: widget.headers,
      // 可见性与前后台共用一次播放决策。
      videoPlayerOptions: VideoPlayerOptions(allowBackgroundPlayback: true),
    );
    _controller = controller;
    _initializationTimeout = Timer(const Duration(seconds: 30), () {
      _fail(controller, '视频连接超时');
    });
    unawaited(_initialize(controller));
  }

  bool _owns(VideoPlayerController controller) =>
      mounted && identical(controller, _controller);

  Future<void> _initialize(VideoPlayerController controller) async {
    try {
      await controller.initialize();
      if (!_owns(controller)) return;
      await controller.setLooping(widget.looping);
      if (!_owns(controller)) return;
      _initializationTimeout?.cancel();
      if (controller.value.errorDescription case final error?) {
        _fail(controller, error);
        return;
      }
      controller.addListener(_onVideoChanged);
      widget.onAspectRatio?.call(controller.value.aspectRatio);
      _syncPlayback();
    } catch (error) {
      _fail(controller, error.toString());
    }
  }

  void _fail(VideoPlayerController controller, String error) {
    if (!_owns(controller)) return;
    setState(() {
      _release();
      _initializationError = error;
    });
  }

  void _onVideoChanged() {
    final controller = _controller!;
    if (controller.value.errorDescription case final error?) {
      _fail(controller, error);
    } else if (controller.value.isCompleted && !widget.looping && !_scrubbing) {
      _wantsPlayback = false;
    }
  }

  Future<void> _syncPlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final play = _shouldPlay;
    if (controller.value.isPlaying == play) return;
    try {
      if (play) {
        if (controller.value.position == controller.value.duration &&
            controller.value.duration > Duration.zero) {
          await controller.seekTo(Duration.zero);
          if (!_owns(controller) || !_shouldPlay) return;
        }
        await controller.play();
      } else {
        await controller.pause();
      }
    } catch (error) {
      _playbackError(controller, error);
    }
  }

  void _playbackError(VideoPlayerController controller, Object error) {
    if (!_owns(controller)) return;
    controller.value = VideoPlayerValue.erroneous(error.toString());
  }

  Future<void> _command(
    VideoPlayerController controller,
    Future<void> Function() run,
  ) async {
    if (!_owns(controller)) return;
    try {
      await run();
    } catch (error) {
      _playbackError(controller, error);
    }
  }

  Future<void> _finishScrub(
    VideoPlayerController controller,
    Duration target,
  ) async {
    await _command(controller, () => controller.seekTo(target));
    if (!_owns(controller)) return;
    _scrubbing = false;
    _syncPlayback();
  }

  Future<void> _openFullscreen(VideoPlayerController controller) async {
    if (!_owns(controller) || _fullscreenRoute != null) return;
    final route = MaterialPageRoute<bool>(
      fullscreenDialog: true,
      builder: (context) => Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(child: _surface(controller, fullscreen: true)),
      ),
    );
    setState(() => _fullscreenRoute = route);
    final retry = await Navigator.of(context).push(route);
    if (!mounted || _fullscreenRoute != route) return;
    setState(() {
      _fullscreenRoute = null;
      _scrubbing = false;
      if (retry == true) _load();
    });
    _syncPlayback();
  }

  void _closeFullscreen() {
    final route = _fullscreenRoute;
    _fullscreenRoute = null;
    if (route == null) return;
    scheduleMicrotask(() {
      if (route.isActive) route.navigator?.removeRoute(route);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return controller == null
        ? _layout(_message(error: _initializationError), widget.quarterTurns)
        : _surface(controller);
  }

  Widget _surface(VideoPlayerController controller, {bool fullscreen = false}) {
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, value, _) {
        final turns = fullscreen
            ? (value.aspectRatio > 1 ? 1 : 0)
            : widget.quarterTurns;
        final showVideo =
            value.isInitialized && (fullscreen || _fullscreenRoute == null);
        return _layout(
          showVideo
              ? _VideoControls(
                  key: ObjectKey(controller),
                  controller: controller,
                  onTogglePlayback: () {
                    _wantsPlayback = !_wantsPlayback;
                    _syncPlayback();
                  },
                  onSkip: (offset) => _command(
                    controller,
                    () => controller.seekTo(value.position + offset),
                  ),
                  onMute: () => _command(
                    controller,
                    () => controller.setVolume(value.volume == 0 ? 1 : 0),
                  ),
                  onScrubStart: () {
                    _scrubbing = true;
                    _syncPlayback();
                  },
                  onScrubEnd: (target) => _finishScrub(controller, target),
                  onFullscreen: fullscreen
                      ? () => Navigator.of(context).pop()
                      : widget.allowFullscreen
                      ? () => _openFullscreen(controller)
                      : null,
                  fullscreen: fullscreen,
                )
              : value.isInitialized
              ? const SizedBox.expand()
              : _message(
                  error: value.errorDescription,
                  retry: fullscreen
                      ? () => Navigator.of(context).pop(true)
                      : null,
                ),
          turns,
          aspectRatio: value.isInitialized ? value.aspectRatio : 16 / 9,
        );
      },
    );
  }

  Widget _layout(Widget child, int turns, {double aspectRatio = 16 / 9}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final surface = ColoredBox(
          color: Colors.black,
          child: RotatedBox(quarterTurns: turns, child: child),
        );
        return constraints.hasBoundedHeight
            ? surface
            : AspectRatio(aspectRatio: aspectRatio, child: surface);
      },
    );
  }

  Widget _message({String? error, VoidCallback? retry}) {
    if (error == null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          ?widget.placeholder,
          const Center(child: CircularProgressIndicator(color: Colors.white)),
        ],
      );
    }
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '视频加载失败\n$error',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                TextButton(
                  onPressed: retry ?? () => setState(_load),
                  child: const Text('重试'),
                ),
                if (widget.openInBrowser case final open?)
                  TextButton(onPressed: open, child: const Text('在浏览器中打开')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoControls extends StatefulWidget {
  const _VideoControls({
    super.key,
    required this.controller,
    required this.onTogglePlayback,
    required this.onSkip,
    required this.onMute,
    required this.onScrubStart,
    required this.onScrubEnd,
    required this.onFullscreen,
    required this.fullscreen,
  });

  final VideoPlayerController controller;
  final VoidCallback onTogglePlayback;
  final ValueChanged<Duration> onSkip;
  final VoidCallback onMute;
  final VoidCallback onScrubStart;
  final ValueChanged<Duration> onScrubEnd;
  final VoidCallback? onFullscreen;
  final bool fullscreen;

  @override
  State<_VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends State<_VideoControls> {
  bool _showControls = true;
  double? _dragPosition;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _restartTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (_dragPosition == null) setState(() => _showControls = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.value;
    final duration = value.duration.inMilliseconds.toDouble();
    final position = (_dragPosition ?? value.position.inMilliseconds.toDouble())
        .clamp(0.0, duration);
    final buffered = value.buffered.fold(
      position,
      (last, range) => last >= range.end.inMilliseconds
          ? last
          : range.end.inMilliseconds.toDouble(),
    );
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() => _showControls = !_showControls);
              _restartTimer();
            },
            child: Center(
              child: AspectRatio(
                aspectRatio: value.aspectRatio,
                child: VideoPlayer(widget.controller),
              ),
            ),
          ),
        ),
        if (value.isBuffering)
          const Center(
            child: IgnorePointer(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
        if (_showControls)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ColoredBox(
              color: Colors.black54,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 7,
                      ),
                    ),
                    child: Slider(
                      max: duration > 0 ? duration : 1,
                      value: position,
                      secondaryTrackValue: buffered.clamp(0.0, duration),
                      onChangeStart: (_) {
                        _hideTimer?.cancel();
                        widget.onScrubStart();
                      },
                      onChanged: duration > 0
                          ? (value) => setState(() => _dragPosition = value)
                          : null,
                      onChangeEnd: (value) {
                        setState(() => _dragPosition = null);
                        widget.onScrubEnd(
                          Duration(milliseconds: value.round()),
                        );
                        _restartTimer();
                      },
                    ),
                  ),
                  Row(
                    children: [
                      _button(Icons.replay_10, '后退10秒', () {
                        widget.onSkip(const Duration(seconds: -10));
                      }),
                      _button(
                        value.isPlaying ? Icons.pause : Icons.play_arrow,
                        value.isPlaying ? '暂停' : '播放',
                        widget.onTogglePlayback,
                      ),
                      _button(Icons.forward_10, '快进10秒', () {
                        widget.onSkip(const Duration(seconds: 10));
                      }),
                      Expanded(
                        child: Text(
                          '${_format(Duration(milliseconds: position.round()))} / ${_format(value.duration)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (widget.onFullscreen != null)
                        _button(
                          value.volume == 0
                              ? Icons.volume_off
                              : Icons.volume_up,
                          value.volume == 0 ? '取消静音' : '静音',
                          widget.onMute,
                        ),
                      if (widget.onFullscreen case final toggle?)
                        _button(
                          widget.fullscreen
                              ? Icons.fullscreen_exit
                              : Icons.fullscreen,
                          widget.fullscreen ? '退出全屏' : '全屏',
                          toggle,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (widget.fullscreen && !_showControls)
          Positioned(
            top: 0,
            right: 0,
            child: _button(Icons.fullscreen_exit, '退出全屏', widget.onFullscreen!),
          ),
      ],
    );
  }

  Widget _button(IconData icon, String tooltip, VoidCallback action) =>
      IconButton(
        tooltip: tooltip,
        color: Colors.white,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        icon: Icon(icon),
        onPressed: () {
          _restartTimer();
          action();
        },
      );

  String _format(Duration duration) =>
      '${duration.inMinutes.toString().padLeft(2, '0')}:'
      '${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
}
