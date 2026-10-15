import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/providers/gallery_providers.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

class VideoTrimmerPage extends ConsumerStatefulWidget {
  final MediaAsset asset;
  const VideoTrimmerPage({super.key, required this.asset});

  @override
  ConsumerState<VideoTrimmerPage> createState() => _VideoTrimmerPageState();
}

class _VideoTrimmerPageState extends ConsumerState<VideoTrimmerPage> {
  double _start = 0, _end = 0, _duration = 0, _previewSec = 0;
  bool _initialized = false,
      _saving = false,
      _previewStart = true,
      _frameLoading = false;
  String? _initError, _frameError;
  Uint8List? _frame;
  Timer? _frameTimer;
  CancelToken? _frameCancel;
  int _frameRequest = 0;

  double get _gap => math.min(0.05, _duration);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _frameTimer?.cancel();
    _frameCancel?.cancel();
    _frameRequest++;
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final response = await ref
          .read(apiClientManagerProvider)
          .get('/API/gallery/${widget.asset.id}/video-info');
      if (!mounted) return;
      final data = response.data as Map<String, dynamic>;
      final duration = (data['duration_ms'] as num).toDouble() / 1000;
      if (!duration.isFinite || duration <= 0) throw StateError('无法读取视频时长');
      double start = 0, end = duration;
      try {
        final edit =
            jsonDecode(widget.asset.editParams ?? '{}') as Map<String, dynamic>;
        if (edit['type'] == 'video') {
          final fps = (edit['fps'] as num?)?.toDouble() ?? 30;
          double boundary(String seconds, String frames) {
            final sec = (edit[seconds] as num?)?.toDouble() ?? 0;
            return sec > 0
                ? sec
                : ((edit[frames] as num?)?.toDouble() ?? 0) /
                      (fps > 0 ? fps : 30);
          }

          start = boundary('trim_start_sec', 'trim_start_frame');
          end = boundary('trim_end_sec', 'trim_end_frame');
          if (end <= 0) end = duration;
        }
      } catch (_) {}
      start = start.isFinite ? start.clamp(0.0, duration) : 0;
      end = end.isFinite ? end.clamp(0.0, duration) : duration;
      if (end - start < math.min(0.05, duration)) {
        start = 0;
        end = duration;
      }
      setState(() {
        _duration = duration;
        _start = start;
        _end = end;
        _initialized = true;
        _initError = null;
      });
      _requestPreview(immediate: true);
    } catch (e) {
      if (mounted) setState(() => _initError = '视频信息加载失败: $e');
    }
  }

  void _setBoundary(double seconds, {required bool start}) {
    setState(() {
      _previewStart = start;
      if (start) {
        _start = seconds.clamp(0.0, math.max(0.0, _end - _gap));
      } else {
        _end = seconds.clamp(math.min(_duration, _start + _gap), _duration);
      }
    });
    _requestPreview();
  }

  void _requestPreview({bool immediate = false}) {
    _frameTimer?.cancel();
    _frameCancel?.cancel();
    final request = ++_frameRequest;
    // 结束点是半开边界，最后一帧需取结尾之前的位置。
    final sec = (_previewStart ? _start : _end)
        .clamp(0.0, math.max(0.0, _duration - 0.05))
        .toDouble();
    setState(() {
      _frameLoading = true;
      _frameError = null;
    });
    if (immediate) {
      unawaited(_fetchFrame(sec, request));
    } else {
      _frameTimer = Timer(
        const Duration(milliseconds: 160),
        () => _fetchFrame(sec, request),
      );
    }
  }

  Future<void> _fetchFrame(double sec, int request) async {
    final cancel = CancelToken();
    _frameCancel = cancel;
    try {
      final response = await ref
          .read(apiClientManagerProvider)
          .getBinary(
            '/API/gallery/${widget.asset.id}/frame',
            queryParams: {'sec': sec.toStringAsFixed(3)},
            cancelToken: cancel,
          );
      if (!mounted || request != _frameRequest) return;
      if (response.data?.isNotEmpty != true) throw StateError('预览帧为空');
      setState(() {
        _frame = response.data;
        _previewSec = sec;
        _frameLoading = false;
      });
    } catch (_) {
      if (!mounted || request != _frameRequest) return;
      setState(() {
        _frameLoading = false;
        _frameError = '此位置的预览加载失败';
      });
    }
  }

  Future<void> _save() async {
    if (!_initialized || _saving) return;
    setState(() => _saving = true);
    try {
      final changed = _start > 0.001 || _end < _duration - 0.001;
      final params = changed
          ? jsonEncode({
              'type': 'video',
              'trim_start_sec': _start,
              'trim_end_sec': _end < _duration - 0.001 ? _end : 0,
              'duration': _duration,
            })
          : null;
      await ref
          .read(mediaAssetListProvider.notifier)
          .setEditParams(widget.asset, params);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(changed ? '剪辑已保存，后端执行编辑时将保留所选片段' : '已清除待执行的剪辑参数'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _time(double seconds) {
    final centiseconds = (seconds * 100).round();
    final minutes = centiseconds ~/ 6000;
    final rest = centiseconds % 6000 / 100;
    return '${minutes.toString().padLeft(2, '0')}:${rest.toStringAsFixed(2).padLeft(5, '0')}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      title: const Text('视频剪辑'),
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          tooltip: '保存',
          icon: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          onPressed: !_initialized || _saving ? null : _save,
        ),
      ],
    ),
    body: !_initialized
        ? Center(
            child: _initError == null
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _initError!,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() => _initError = null);
                          _load();
                        },
                        child: const Text('重试'),
                      ),
                    ],
                  ),
          )
        : LayoutBuilder(
            builder: (_, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                children: [
                  SizedBox(
                    height: (constraints.maxHeight * 0.55).clamp(140.0, 460.0),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_frame != null)
                          Positioned.fill(
                            child: Image.memory(
                              _frame!,
                              fit: BoxFit.contain,
                              gaplessPlayback: true,
                            ),
                          ),
                        if (_frameLoading)
                          const Positioned(
                            right: 12,
                            top: 12,
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        if (_frameError != null)
                          Center(
                            child: DecoratedBox(
                              decoration: const BoxDecoration(
                                color: Colors.black87,
                              ),
                              child: TextButton(
                                onPressed: () =>
                                    _requestPreview(immediate: true),
                                child: Text('$_frameError · 重试'),
                              ),
                            ),
                          ),
                        if (_frame != null)
                          Positioned(
                            left: 8,
                            bottom: 8,
                            child: DecoratedBox(
                              decoration: const BoxDecoration(
                                color: Colors.black87,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text(
                                  '预览 ${_time(_previewSec)}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    children: [
                      Text(
                        '保留 ${(_end - _start).toStringAsFixed(2)} 秒',
                        style: const TextStyle(color: Colors.white),
                      ),
                      Text(
                        '原长 ${_time(_duration)}',
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                  RangeSlider(
                    values: RangeValues(_start, _end),
                    min: 0,
                    max: _duration,
                    labels: RangeLabels(_time(_start), _time(_end)),
                    onChanged: _saving
                        ? null
                        : (values) {
                            if (values.end - values.start < _gap) return;
                            setState(() {
                              _previewStart = values.start != _start;
                              _start = values.start;
                              _end = values.end;
                            });
                            _requestPreview();
                          },
                    onChangeEnd: (_) => _requestPreview(immediate: true),
                  ),
                  _boundaryRow(true),
                  _boundaryRow(false),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        '选定起点或终点，使用 ±0.1 秒微调',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () {
                                setState(() {
                                  _start = 0;
                                  _end = _duration;
                                  _previewStart = true;
                                });
                                _requestPreview(immediate: true);
                              },
                        child: const Text('完整视频'),
                      ),
                    ],
                  ),
                  const Text(
                    '仅保存剪辑参数；原文件在后端执行编辑时更新',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
  );

  Widget _boundaryRow(bool start) {
    final seconds = start ? _start : _end;
    final label = start ? '起点' : '终点';
    final selected = _previewStart == start;
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: _saving
                ? null
                : () {
                    setState(() => _previewStart = start);
                    _requestPreview(immediate: true);
                  },
            style: TextButton.styleFrom(
              foregroundColor: selected ? Colors.amber : Colors.white70,
            ),
            child: Text('$label ${_time(seconds)}'),
          ),
        ),
        IconButton(
          tooltip: '$label后退0.1秒',
          onPressed: _saving
              ? null
              : () => _setBoundary(seconds - 0.1, start: start),
          icon: const Icon(Icons.remove, color: Colors.white70),
        ),
        IconButton(
          tooltip: '$label前进0.1秒',
          onPressed: _saving
              ? null
              : () => _setBoundary(seconds + 0.1, start: start),
          icon: const Icon(Icons.add, color: Colors.white70),
        ),
      ],
    );
  }
}
