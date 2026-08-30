import 'dart:convert';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/providers/gallery_providers.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';
import 'package:video_player/video_player.dart';

/// 视频剪辑页面
///
/// 时间单位统一为**秒**（以 video_player 提供的真实时长为准），不再使用
/// 估算帧数 —— 旧实现硬编码 30 FPS 导致 24/60 FPS 视频的剪辑点完全错误。
///
/// 保存的 edit_params 契约（与后端 gizmos `ApplyVideoEdit` 对齐）：
///   {"type":"video","trim_start_sec":double,"trim_end_sec":double,"duration":double}
/// 其中 trim_end_sec <= 0 表示"到视频结尾"。
class VideoTrimmerPage extends ConsumerStatefulWidget {
  final MediaAsset asset;

  const VideoTrimmerPage({super.key, required this.asset});

  @override
  ConsumerState<VideoTrimmerPage> createState() => _VideoTrimmerPageState();
}

class _VideoTrimmerPageState extends ConsumerState<VideoTrimmerPage> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  /// 剪辑起止秒数；[_endSec] 默认等于视频总时长
  double _startSec = 0;
  double _endSec = 0;

  /// 视频总时长（秒），来自播放器初始化结果，真实可靠
  double _duration = 0;

  bool _initialized = false;
  bool _saving = false;

  /// 容差：低于该值视为"从头/到结尾"，避免浮点噪声
  static const double _eps = 0.05;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _initVideo() async {
    final apiClient = ref.read(apiClientManagerProvider);
    final baseUrl = apiClient.baseUrl;
    final headers = apiClient.headers;
    final videoUrl = '$baseUrl/API/gallery/${widget.asset.id}/file';

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(videoUrl),
      httpHeaders: headers,
    );

    await controller.initialize();

    final durationSec = controller.value.duration.inMilliseconds / 1000.0;

    // 解析已有编辑参数（优先秒数；旧版帧数协议作为后备）
    double startSec = 0;
    double endSec = durationSec;
    final params = widget.asset.editParams;
    if (params != null) {
      try {
        final json = jsonDecode(params) as Map<String, dynamic>;
        if (json['type'] == 'video') {
          final s = (json['trim_start_sec'] as num?)?.toDouble();
          final e = (json['trim_end_sec'] as num?)?.toDouble();
          if (s != null && s > 0) startSec = s;
          if (e != null && e > 0) endSec = e;
          if ((s == null || s <= 0) && json['trim_start_frame'] is int) {
            final fps = (json['fps'] as num?)?.toDouble() ?? 30.0;
            startSec = (json['trim_start_frame'] as int) / (fps > 0 ? fps : 30);
          }
          if ((e == null || e <= 0) && json['trim_end_frame'] is int) {
            final fps = (json['fps'] as num?)?.toDouble() ?? 30.0;
            final f = (json['trim_end_frame'] as int);
            if (f > 0) endSec = f / (fps > 0 ? fps : 30);
          }
        }
      } catch (_) {}
    }

    // 边界收敛
    if (startSec < 0) startSec = 0;
    if (endSec > durationSec) endSec = durationSec;
    if (endSec <= startSec + _eps) endSec = durationSec;

    if (mounted) {
      setState(() {
        _videoController = controller;
        _chewieController = ChewieController(
          videoPlayerController: controller,
          autoPlay: false,
          looping: true,
          allowFullScreen: false,
          showControls: true,
        );
        _duration = durationSec;
        _startSec = startSec;
        _endSec = endSec;
        _initialized = true;
      });
    }
  }

  /// 是否实际发生了剪辑（起止点有一处偏离"从头到尾"即视为有剪辑）
  bool get _hasTrim => _startSec > _eps || _endSec < _duration - _eps;

  String? _buildEditParamsJson() {
    if (!_hasTrim) return null;
    final map = <String, dynamic>{
      'type': 'video',
      'trim_start_sec': _startSec,
      // 到结尾时传 0（后端语义：<=0 表示到结尾）
      'trim_end_sec': _endSec < _duration - _eps ? _endSec : 0,
      'duration': _duration,
    };
    return jsonEncode(map);
  }

  String _formatTime(double sec) {
    final s = sec < 0 ? 0 : sec;
    final min = (s / 60).floor();
    final rem = (s % 60);
    final whole = rem.floor();
    final tenth = ((rem - whole) * 10).floor();
    return '${min.toString().padLeft(2, '0')}:${whole.toString().padLeft(2, '0')}.$tenth';
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final db = ref.read(galleryDatabaseProvider);
      final editParams = _buildEditParamsJson();
      final updatedAsset = widget.asset.copyWith(
        editParams: editParams,
        clearEditParams: editParams == null,
      );
      await db.updateMediaAsset(updatedAsset);

      // 刷新列表
      await ref.read(mediaAssetListProvider.notifier).refresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              editParams == null ? '已还原为完整视频' : '剪辑参数已保存，同步后将应用',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('视频剪辑'),
        actions: [
          IconButton(
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check),
            tooltip: '保存',
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: !_initialized
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 播放器
                SizedBox(
                  height: 250,
                  child: Chewie(controller: _chewieController!),
                ),
                const SizedBox(height: 16),
                // 时间轴滑块（秒）
                _buildTimeline(),
                const SizedBox(height: 16),
                // 快捷按钮
                _buildQuickActions(),
                const SizedBox(height: 8),
                // 信息
                Text(
                  '起始: ${_formatTime(_startSec)}  |  结束: ${_formatTime(_endSec)}  |  总长: ${_formatTime(_duration)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 16),
              ],
            ),
    );
  }

  Widget _buildTimeline() {
    final maxSec = _duration > 0 ? _duration : 1.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildSliderRow(
            label: '起始',
            color: Colors.green,
            value: _startSec,
            max: maxSec,
            onChanged: (v) {
              setState(() {
                _startSec = v;
                // 保证最小片段长度
                if (_startSec >= _endSec - _eps) {
                  _startSec = (_endSec - _eps).clamp(0.0, maxSec).toDouble();
                }
              });
            },
          ),
          _buildSliderRow(
            label: '结束',
            color: Colors.red,
            value: _endSec,
            max: maxSec,
            onChanged: (v) {
              setState(() {
                _endSec = v;
                if (_endSec <= _startSec + _eps) {
                  _endSec = (_startSec + _eps).clamp(0.0, maxSec).toDouble();
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required Color color,
    required double value,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(0.0, max).toDouble(),
            min: 0,
            max: max,
            activeColor: color,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 64,
          child: Text(_formatTime(value),
              style: const TextStyle(color: Colors.white54, fontSize: 11),
              textAlign: TextAlign.right),
        ),
      ],
    );
  }

  /// 当前播放位置（秒）
  double? get _currentPositionSec {
    final pos = _videoController?.value.position;
    if (pos == null) return null;
    return pos.inMilliseconds / 1000.0;
  }

  Widget _buildQuickActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ActionButton(
          label: '剪开头',
          icon: Icons.skip_previous,
          onTap: () {
            final pos = _currentPositionSec;
            if (pos == null) return;
            setState(() {
              _startSec = pos.clamp(0.0, _endSec - _eps).toDouble();
            });
          },
        ),
        _ActionButton(
          label: '剪结尾',
          icon: Icons.skip_next,
          onTap: () {
            final pos = _currentPositionSec;
            if (pos == null) return;
            setState(() {
              _endSec = pos.clamp(_startSec + _eps, _duration).toDouble();
            });
          },
        ),
        _ActionButton(
          label: '选取中间',
          icon: Icons.center_focus_strong,
          onTap: () {
            final pos = _currentPositionSec;
            if (pos == null) return;
            final half = (_endSec - _startSec) / 2;
            setState(() {
              _startSec = (pos - half).clamp(0.0, _duration).toDouble();
              _endSec = (pos + half).clamp(0.0, _duration).toDouble();
              if (_endSec <= _startSec + _eps) {
                _endSec = (_startSec + _eps).clamp(0.0, _duration).toDouble();
              }
            });
          },
        ),
        _ActionButton(
          label: '重置',
          icon: Icons.refresh,
          onTap: () {
            setState(() {
              _startSec = 0;
              _endSec = _duration;
            });
          },
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 24),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
