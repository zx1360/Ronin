import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/providers/gallery_providers.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

/// 视频剪辑页面
/// 使用 video_player + chewie 播放，时间轴拖拽选择起止帧
class VideoTrimmerPage extends ConsumerStatefulWidget {
  final MediaAsset asset;

  const VideoTrimmerPage({super.key, required this.asset});

  @override
  ConsumerState<VideoTrimmerPage> createState() => _VideoTrimmerPageState();
}

class _VideoTrimmerPageState extends ConsumerState<VideoTrimmerPage> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  /// 剪辑起始帧
  int _startFrame = 0;
  /// 剪辑结束帧 (0 表示末尾)
  int _endFrame = 0;

  /// 视频总帧数
  int _totalFrames = 0;
  /// FPS
  double _fps = 30.0;

  bool _initialized = false;
  bool _saving = false;

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

    final dur = controller.value.duration;
    const fps = 30.0; // video_player 2.x 不提供 fpsHint，默认 30 FPS
    final totalFrames = (dur.inMilliseconds / 1000 * fps).round();

    // 解析已有编辑参数
    int startFrame = 0;
    int endFrame = 0;
    final params = widget.asset.editParams;
    if (params != null) {
      try {
        final json = jsonDecode(params) as Map<String, dynamic>;
        if (json['type'] == 'video') {
          startFrame = json['trim_start_frame'] as int? ?? 0;
          endFrame = json['trim_end_frame'] as int? ?? 0;
        }
      } catch (_) {}
    }

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
        _fps = fps;
        _totalFrames = totalFrames;
        _startFrame = startFrame;
        _endFrame = endFrame > 0 ? endFrame : totalFrames;
        _initialized = true;
      });
    }
  }

  String _buildEditParamsJson() {
    final map = <String, dynamic>{
      'type': 'video',
      'trim_start_frame': _startFrame,
      'trim_end_frame': _endFrame < _totalFrames ? _endFrame : 0,
      'fps': _fps,
      'trim_start_sec': _frameToSeconds(_startFrame),
      'trim_end_sec': _frameToSeconds(_endFrame < _totalFrames ? _endFrame : _totalFrames),
    };
    return jsonEncode(map);
  }

  double _frameToSeconds(int frame) {
    return _fps > 0 ? frame / _fps : 0;
  }

  String _formatTime(int frame) {
    final sec = _frameToSeconds(frame);
    final min = (sec / 60).floor();
    final s = (sec % 60).floor();
    return '${min.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final db = ref.read(galleryDatabaseProvider);
      final updatedAsset = widget.asset.copyWith(
        editParams: _buildEditParamsJson(),
      );
      await db.updateMediaAsset(updatedAsset);

      // 刷新列表
      await ref.read(mediaAssetListProvider.notifier).refresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('剪辑参数已保存，同步后将应用'),
            duration: Duration(seconds: 2),
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
                // 时间轴滑块
                _buildTimeline(),
                const SizedBox(height: 16),
                // 快捷按钮
                _buildQuickActions(),
                const SizedBox(height: 8),
                // 信息
                Text(
                  '起始: ${_formatTime(_startFrame)} (帧 $_startFrame)  |  '
                  '结束: ${_formatTime(_endFrame)} (帧 $_endFrame)  |  '
                  'FPS: ${_fps.toStringAsFixed(1)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 16),
              ],
            ),
    );
  }

  Widget _buildTimeline() {
    final maxFrames = _totalFrames > 0 ? _totalFrames : 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // 起始帧滑块
          Row(
            children: [
              const SizedBox(
                  width: 40,
                  child: Text('起始',
                      style: TextStyle(color: Colors.white54, fontSize: 11))),
              Expanded(
                child: Slider(
                  value: _startFrame.toDouble(),
                  min: 0,
                  max: maxFrames.toDouble(),
                  activeColor: Colors.green,
                  onChanged: (v) {
                    setState(() {
                      _startFrame = v.round();
                      if (_startFrame >= _endFrame) {
                        _startFrame = _endFrame - 1;
                      }
                    });
                  },
                ),
              ),
              SizedBox(
                width: 60,
                child: Text('$_startFrame帧',
                    style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ),
            ],
          ),
          // 结束帧滑块
          Row(
            children: [
              const SizedBox(
                  width: 40,
                  child: Text('结束',
                      style: TextStyle(color: Colors.white54, fontSize: 11))),
              Expanded(
                child: Slider(
                  value: _endFrame.toDouble(),
                  min: 0,
                  max: maxFrames.toDouble(),
                  activeColor: Colors.red,
                  onChanged: (v) {
                    setState(() {
                      _endFrame = v.round();
                      if (_endFrame <= _startFrame) {
                        _endFrame = _startFrame + 1;
                      }
                    });
                  },
                ),
              ),
              SizedBox(
                width: 60,
                child: Text('$_endFrame帧',
                    style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ActionButton(
          label: '剪开头',
          icon: Icons.skip_previous,
          onTap: () {
            final currentPos = _videoController?.value.position;
            if (currentPos != null && _fps > 0) {
              final frame = (currentPos.inMilliseconds / 1000 * _fps).round();
              setState(() => _startFrame = frame.clamp(0, _endFrame - 1));
            }
          },
        ),
        _ActionButton(
          label: '剪结尾',
          icon: Icons.skip_next,
          onTap: () {
            final currentPos = _videoController?.value.position;
            if (currentPos != null && _fps > 0) {
              final frame = (currentPos.inMilliseconds / 1000 * _fps).round();
              setState(() =>
                  _endFrame = frame.clamp(_startFrame + 1, _totalFrames));
            }
          },
        ),
        _ActionButton(
          label: '选取中间',
          icon: Icons.center_focus_strong,
          onTap: () {
            final currentPos = _videoController?.value.position;
            if (currentPos != null && _fps > 0) {
              final frame = (currentPos.inMilliseconds / 1000 * _fps).round();
              final half = (_endFrame - _startFrame) ~/ 2;
              setState(() {
                _startFrame = (frame - half).clamp(0, _totalFrames);
                _endFrame = (frame + half).clamp(0, _totalFrames);
                if (_startFrame >= _endFrame) {
                  _endFrame = _startFrame + 1;
                }
              });
            }
          },
        ),
        _ActionButton(
          label: '重置',
          icon: Icons.refresh,
          onTap: () {
            setState(() {
              _startFrame = 0;
              _endFrame = _totalFrames;
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
