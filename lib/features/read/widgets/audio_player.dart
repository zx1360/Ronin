import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'dart:async';

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
  void dispose() {
    _disposed = true;
    _stateSub?.cancel();
    _durSub?.cancel();
    _posSub?.cancel();
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    try {
      await _player.stop();
      await _player.setSourceUrl(widget.url);
      await _player.resume();
    } catch (e) {
      // 简单容错：回退到 play 调用
      try {
        await _player.play(UrlSource(widget.url));
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
