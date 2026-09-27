import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/providers/gallery_providers.dart';

/// 视频剪辑页面（纯图片帧预览，无视频播放器）
///
/// 设计说明：
/// - 预览区为**图片组件**：通过后端 `GET /API/gallery/:id/frame?sec=` 提取
///   指定秒数的单帧 JPEG 显示，拖动滑块时实时刷新，不依赖视频 seek 的缓冲延迟；
/// - 拖动**起始**滑块 → 预览起始帧画面；拖动**结束**滑块 → 预览结束帧画面；
/// - 视频时长由后端 `GET /API/gallery/:id/video-info` 提供；
/// - 保存的 edit_params 契约与后端 `ApplyVideoEdit` 对齐 (见 media_edit_params.dart)。
///
/// 时长/区间/帧预览/保存均由 [VideoTrim] 持有, 页面只保留布局与滑块。
class VideoTrimmerPage extends ConsumerStatefulWidget {
  final MediaAsset asset;

  const VideoTrimmerPage({super.key, required this.asset});

  @override
  ConsumerState<VideoTrimmerPage> createState() => _VideoTrimmerPageState();
}

class _VideoTrimmerPageState extends ConsumerState<VideoTrimmerPage> {
  @override
  void initState() {
    super.initState();
    ref.read(videoTrimProvider.notifier).load(widget.asset);
  }

  String _formatTime(double sec) {
    final s = sec < 0 ? 0 : sec;
    final min = (s / 60).floor();
    final rem = (s % 60);
    final whole = rem.floor();
    final tenth = ((rem - whole) * 10).floor();
    return '${min.toString().padLeft(2, '0')}:${whole.toString().padLeft(2, '0')}.$tenth';
  }

  /// 保存剪辑参数; 未剪辑时清除参数
  Future<void> _save() async {
    try {
      await ref.read(videoTrimProvider.notifier).save();
      final hasTrim = ref.read(videoTrimProvider).hasTrim;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              hasTrim ? '剪辑参数已保存，同步后将应用' : '已还原为完整视频',
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
    }
  }

  // UI

  @override
  Widget build(BuildContext context) {
    final trim = ref.watch(videoTrimProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('视频剪辑'),
        actions: [
          IconButton(
            icon: trim.saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check),
            tooltip: '保存',
            onPressed: trim.saving ? null : _save,
          ),
        ],
      ),
      body: !trim.initialized
          ? (trim.initError != null ? _buildInitError(trim) : const Center(child: CircularProgressIndicator()))
          : Column(
              children: [
                // 帧画面预览（图片组件）
                Container(
                  height: 250,
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: trim.frameBytes != null
                      ? Image.memory(trim.frameBytes!, fit: BoxFit.contain, gaplessPlayback: true)
                      : const CircularProgressIndicator(color: Colors.white54),
                ),
                const SizedBox(height: 16),
                // 时间轴滑块（秒）
                _buildTimeline(trim),
                const SizedBox(height: 12),
                // 信息 + 重置
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '起始: ${_formatTime(trim.startSec)}  |  结束: ${_formatTime(trim.endSec)}  |  总长: ${_formatTime(trim.durationSec)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(width: 16),
                    TextButton(
                      onPressed: () => ref.read(videoTrimProvider.notifier).reset(),
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
  Widget _buildInitError(VideoTrimState trim) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              trim.initError ?? '加载失败',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.read(videoTrimProvider.notifier).retry(),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(VideoTrimState trim) {
    final maxSec = trim.durationSec > 0 ? trim.durationSec : 1.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // 起始滑块：拖动时预览"起始帧"
          _buildSliderRow(
            label: '起始',
            color: Colors.green,
            value: trim.startSec,
            max: maxSec,
            onChanged: (v) =>
                ref.read(videoTrimProvider.notifier).setStart(v, maxSec),
            onChangeEnd: (v) =>
                ref.read(videoTrimProvider.notifier).commitScrub(v),
          ),
          // 结束滑块：拖动时预览"结束帧"
          _buildSliderRow(
            label: '结束',
            color: Colors.red,
            value: trim.endSec,
            max: maxSec,
            onChanged: (v) =>
                ref.read(videoTrimProvider.notifier).setEnd(v, maxSec),
            onChangeEnd: (v) =>
                ref.read(videoTrimProvider.notifier).commitScrub(v),
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
