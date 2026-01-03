import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:torrid/core/services/io/io_service.dart';

class SimpleAudioPlayer extends StatefulWidget {
  final String url;
  const SimpleAudioPlayer({super.key, required this.url});

  @override
  State<SimpleAudioPlayer> createState() => _SimpleAudioPlayerState();
}

class _SimpleAudioPlayerState extends State<SimpleAudioPlayer> {
  final AudioPlayer _player = AudioPlayer();
  PlayerState _state = PlayerState.stopped;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<Duration>? _posSub;
  bool _disposed = false;
  Source? _source;

  @override
  void initState() {
    super.initState();
    // 使用非循环播放模式，兼容流媒体
    _player.setReleaseMode(ReleaseMode.stop);
    _stateSub = _player.onPlayerStateChanged.listen((s) {
      if (!mounted || _disposed) return;
      setState(() => _state = s);
    });
    _durSub = _player.onDurationChanged.listen((d) {
      if (!mounted || _disposed) return;
      setState(() => _dur = d);
    });
    _posSub = _player.onPositionChanged.listen((p) {
      if (!mounted || _disposed) return;
      setState(() => _pos = p);
    });
  }

  @override
  void didUpdateWidget(covariant SimpleAudioPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当URL变化时，清空旧的source与进度，避免继续使用旧音频
    if (oldWidget.url != widget.url) {
      _source = null;
      _pos = Duration.zero;
      _dur = Duration.zero;
      _player.stop();
      setState(() {});
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _stateSub?.cancel();
    _durSub?.cancel();
    _posSub?.cancel();
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  Future<Source> _buildSource(String input) async {
    // 本地相对路径: 以'/'开头，拼接外部私有目录
    if (input.startsWith('/')) {
      final base = (await IoService.externalStorageDir).path;
      final full = p.normalize(p.join(base, input.replaceFirst('/', '')));
      return DeviceFileSource(full);
    }
    // file:// 或 绝对路径
    if (input.startsWith('file://')) {
      return UrlSource(input);
    }
    // 移动端常见绝对路径
    if (Platform.isAndroid || Platform.isIOS) {
      if (input.startsWith('/storage') || input.startsWith('/data/')) {
        return DeviceFileSource(input);
      }
    }
    // Windows/macOS 绝对路径或 UNC 路径
    final isWindowsAbs = RegExp(r'^[A-Za-z]:\\').hasMatch(input) || input.startsWith('\\\\');
    if (isWindowsAbs || p.isAbsolute(input)) {
      return DeviceFileSource(input);
    }
    // 尝试在外部目录下解析相对路径（如 changya/xxx.mp3）
    try {
      final base = (await IoService.externalStorageDir).path;
      final probe = p.normalize(p.join(base, input));
      if (await File(probe).exists()) {
        return DeviceFileSource(probe);
      }
    } catch (_) {}
    // 其他情况当作网络地址
    return UrlSource(input);
  }

  Future<void> _play() async {
    try {
      await _player.stop();
      _source ??= await _buildSource(widget.url);
      await _player.setSource(_source!);
      await _player.resume();
    } catch (e) {
      // 简单容错：回退到 play 调用
      try {
        final s = await _buildSource(widget.url);
        await _player.play(s);
      } catch (_) {}
    }
  }

  Future<void> _pause() async => _player.pause();
  Future<void> _resume() async => _player.resume();
  Future<void> _stop() async => _player.stop();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            FilledButton.icon(
              onPressed: _state == PlayerState.playing ? _pause : _play,
              icon: Icon(_state == PlayerState.playing ? Icons.pause : Icons.play_arrow),
              label: Text(_state == PlayerState.playing ? '暂停' : '播放'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _state == PlayerState.paused ? _resume : _stop,
              icon: Icon(_state == PlayerState.paused ? Icons.play_arrow : Icons.stop),
              label: Text(_state == PlayerState.paused ? '继续' : '停止'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: _pos.inMilliseconds.toDouble().clamp(0, _dur.inMilliseconds.toDouble()),
          min: 0,
          max: _dur.inMilliseconds.toDouble().clamp(0, double.infinity),
          onChanged: (v) async {
            final target = Duration(milliseconds: v.toInt());
            await _player.seek(target);
          },
          activeColor: cs.primary,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_fmt(_pos)),
            Text(_fmt(_dur)),
          ],
        ),
      ],
    );
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
  }
}
