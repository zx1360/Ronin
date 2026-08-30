import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/providers/gallery_providers.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

/// 视频剪辑页面（纯图片帧预览，无视频播放器）
///
/// 设计说明：
/// - 预览区为**图片组件**：通过后端 `GET /API/gallery/:id/frame?sec=` 提取
///   指定秒数的单帧 JPEG 显示，拖动滑块时实时刷新，不依赖视频 seek 的缓冲延迟；
/// - 拖动**起始**滑块 → 预览起始帧画面；拖动**结束**滑块 → 预览结束帧画面；
/// - 视频时长由后端 `GET /API/gallery/:id/video-info` 提供；
/// - 保存的 edit_params 契约（与后端 gizmos `ApplyVideoEdit` 对齐）：
///   `{"type":"video","trim_start_sec":double,"trim_end_sec":double,"duration":double}`
///   其中 trim_end_sec <= 0 表示"到视频结尾"。
class VideoTrimmerPage extends ConsumerStatefulWidget {
  final MediaAsset asset;

  const VideoTrimmerPage({super.key, required this.asset});

  @override
  ConsumerState<VideoTrimmerPage> createState() => _VideoTrimmerPageState();
}

class _VideoTrimmerPageState extends ConsumerState<VideoTrimmerPage> {
  /// 剪辑起止秒数；[_endSec] 默认等于视频总时长
  double _startSec = 0;
  double _endSec = 0;

  /// 视频总时长（秒），来自后端 video-info
  double _duration = 0;

  bool _initialized = false;
  bool _saving = false;

  /// 初始化失败信息（video-info 请求失败等），非空时显示错误页
  String? _initError;

  // ============ 帧画面预览（图片） ============

  /// 当前预览帧（JPEG 字节）
  Uint8List? _frameBytes;

  /// 取帧节流定时器与请求序号（防乱序覆盖）
  Timer? _frameThrottle;
  int _frameReqSerial = 0;

  /// 容差：低于该值视为"从头/到结尾"，避免浮点噪声
  static const double _eps = 0.05;

  @override
  void initState() {
    super.initState();
    _loadVideoInfo();
  }

  @override
  void dispose() {
    _frameThrottle?.cancel();
    super.dispose();
  }

  /// 获取视频时长/分辨率，随后加载起始位置帧画面
  Future<void> _loadVideoInfo() async {
    final api = ref.read(apiClientManagerProvider);
    try {
      final resp = await api.get(
        '/API/gallery/${widget.asset.id}/video-info',
      );
      if (!mounted) return;
      final data = resp.data as Map<String, dynamic>?;
      final durationMs = (data?['duration_ms'] as num?)?.toInt() ?? 0;
      if (durationMs <= 0) {
        setState(() => _initError = '无法获取视频时长');
        return;
      }

      final durationSec = durationMs / 1000.0;

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

      setState(() {
        _duration = durationSec;
        _startSec = startSec;
        _endSec = endSec;
        _initialized = true;
      });
      _fetchFrame(startSec);
    } catch (e) {
      if (mounted) setState(() => _initError = '视频信息加载失败: $e');
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

  // ============ 帧画面预览 ============

  /// 拖动滑块：更新数值并节流请求该位置的帧画面
  void _onTrimChanged({required bool isStart, required double v, required double maxSec}) {
    setState(() {
      if (isStart) {
        _startSec = v;
        if (_startSec >= _endSec - _eps) {
          _startSec = (_endSec - _eps).clamp(0.0, maxSec).toDouble();
        }
      } else {
        _endSec = v;
        if (_endSec <= _startSec + _eps) {
          _endSec = (_startSec + _eps).clamp(0.0, maxSec).toDouble();
        }
      }
    });
    _scheduleFrameFetch(isStart ? _startSec : _endSec);
  }

  /// 滑块松手：立即拉取最终帧（画面停留在该位置）
  void _onTrimScrubEnd(double v) {
    _frameThrottle?.cancel();
    _fetchFrame(v);
  }

  /// 节流调度取帧：拖动期间最多约 8 次/秒请求后端
  void _scheduleFrameFetch(double sec) {
    _frameThrottle?.cancel();
    _frameThrottle = Timer(const Duration(milliseconds: 120), () {
      _fetchFrame(sec);
    });
  }

  /// 请求后端提取该秒数的单帧 JPEG 并显示（带序号防乱序覆盖）
  Future<void> _fetchFrame(double sec) async {
    final api = ref.read(apiClientManagerProvider);
    final serial = ++_frameReqSerial;
    try {
      final resp = await api.getBinary(
        '/API/gallery/${widget.asset.id}/frame',
        queryParams: {'sec': sec.toStringAsFixed(2)},
      );
      if (!mounted || serial != _frameReqSerial) return;
      setState(() => _frameBytes = resp.data);
    } catch (_) {
      // 取帧失败静默：保留上一帧画面，不影响剪辑
    }
  }

  // ============ 保存 ============

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

  // ============ UI ============

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
          ? (_initError != null ? _buildInitError() : const Center(child: CircularProgressIndicator()))
          : Column(
              children: [
                // 帧画面预览（图片组件）
                Container(
                  height: 250,
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: _frameBytes != null
                      ? Image.memory(_frameBytes!, fit: BoxFit.contain, gaplessPlayback: true)
                      : const CircularProgressIndicator(color: Colors.white54),
                ),
                const SizedBox(height: 16),
                // 时间轴滑块（秒）
                _buildTimeline(),
                const SizedBox(height: 12),
                // 信息 + 重置
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '起始: ${_formatTime(_startSec)}  |  结束: ${_formatTime(_endSec)}  |  总长: ${_formatTime(_duration)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(width: 16),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _startSec = 0;
                          _endSec = _duration;
                        });
                        _fetchFrame(_startSec);
                      },
                      child: const Text('重置', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '拖动滑块预览对应帧画面，保存后由后端应用剪辑',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
                const SizedBox(height: 16),
              ],
            ),
    );
  }

  /// 初始化失败页
  Widget _buildInitError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _initError ?? '加载失败',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _initError = null;
                _initialized = false;
              });
              _loadVideoInfo();
            },
            child: const Text('重试'),
          ),
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
          // 起始滑块：拖动时预览"起始帧"
          _buildSliderRow(
            label: '起始',
            color: Colors.green,
            value: _startSec,
            max: maxSec,
            onChanged: (v) => _onTrimChanged(isStart: true, v: v, maxSec: maxSec),
            onChangeEnd: _onTrimScrubEnd,
          ),
          // 结束滑块：拖动时预览"结束帧"
          _buildSliderRow(
            label: '结束',
            color: Colors.red,
            value: _endSec,
            max: maxSec,
            onChanged: (v) => _onTrimChanged(isStart: false, v: v, maxSec: maxSec),
            onChangeEnd: _onTrimScrubEnd,
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
    ValueChanged<double>? onChangeEnd,
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
            onChangeEnd: onChangeEnd,
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
}
