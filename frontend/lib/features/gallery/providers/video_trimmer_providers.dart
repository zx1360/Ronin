import 'dart:async';
import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/core/api/generated/api_contract.dart' show ApiPath;
import 'package:torrid/features/gallery/models/media_asset.dart';
import 'package:torrid/features/gallery/models/media_edit_params.dart';
import 'package:torrid/features/gallery/models/media_patch_intent.dart';
import 'package:torrid/features/gallery/providers/media_providers.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

part 'video_trimmer_providers.g.dart';

/// 视频剪辑状态
class VideoTrimState {
  const VideoTrimState({
    this.asset,
    this.durationSec = 0,
    this.startSec = 0,
    this.endSec = 0,
    this.initialized = false,
    this.saving = false,
    this.frameBytes,
    this.initError,
  });

  /// 被剪辑的媒体文件
  final MediaAsset? asset;

  /// 视频总时长 (秒), 来自后端 video-info
  final double durationSec;

  /// 剪辑起止秒数
  final double startSec;
  final double endSec;

  final bool initialized;
  final bool saving;

  /// 当前预览帧 (JPEG 字节)
  final Uint8List? frameBytes;

  /// 初始化失败信息, 非空时显示错误页
  final String? initError;

  /// 起止点是否偏离"从头到尾"
  bool get hasTrim =>
      startSec > VideoEditParams.eps ||
      endSec < durationSec - VideoEditParams.eps;

  VideoTrimState copyWith({
    MediaAsset? asset,
    double? durationSec,
    double? startSec,
    double? endSec,
    bool? initialized,
    bool? saving,
    Uint8List? frameBytes,
    String? initError,
    bool clearInitError = false,
  }) {
    return VideoTrimState(
      asset: asset ?? this.asset,
      durationSec: durationSec ?? this.durationSec,
      startSec: startSec ?? this.startSec,
      endSec: endSec ?? this.endSec,
      initialized: initialized ?? this.initialized,
      saving: saving ?? this.saving,
      frameBytes: frameBytes ?? this.frameBytes,
      initError: clearInitError ? null : (initError ?? this.initError),
    );
  }
}

/// 视频剪辑: 时长加载 / 区间调整 / 帧预览 / 保存
///
/// 仅用后端 `frame` 接口的单帧图片做预览, 不引入视频播放器。
@riverpod
class VideoTrim extends _$VideoTrim {
  Timer? _frameThrottle;
  int _frameReqSerial = 0;
  bool _disposed = false;

  @override
  VideoTrimState build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _frameThrottle?.cancel();
      _frameThrottle = null;
    });
    return const VideoTrimState();
  }

  /// 读取视频时长, 按已有参数初始化剪辑区间并预览起始帧
  Future<void> load(MediaAsset asset) async {
    state = VideoTrimState(asset: asset);
    final api = ref.read(apiClientManagerProvider);
    try {
      final resp = await api.get(ApiPath.galleryIdTypePath(asset.id, 'video-info'));
      if (_disposed) return;

      final data = resp.data as Map<String, dynamic>?;
      final durationMs = (data?['duration_ms'] as num?)?.toInt() ?? 0;
      if (durationMs <= 0) {
        state = state.copyWith(initError: '无法获取视频时长');
        return;
      }

      final durationSec = durationMs / 1000.0;
      final params =
          VideoEditParams.parse(asset.editParams, durationSec: durationSec);
      state = state.copyWith(
        durationSec: durationSec,
        startSec: params.startSec,
        endSec: params.endSec,
        initialized: true,
      );
      await _fetchFrame(params.startSec);
    } catch (e) {
      if (!_disposed) state = state.copyWith(initError: '视频信息加载失败: $e');
    }
  }

  /// 初始化失败后重试
  Future<void> retry() async {
    final asset = state.asset;
    if (asset == null) return;
    await load(asset);
  }

  /// 拖动起始滑块
  void setStart(double value, double maxSec) {
    var start = value;
    if (start >= state.endSec - VideoEditParams.eps) {
      start =
          (state.endSec - VideoEditParams.eps).clamp(0.0, maxSec).toDouble();
    }
    state = state.copyWith(startSec: start);
    _scheduleFrameFetch(start);
  }

  /// 拖动结束滑块
  void setEnd(double value, double maxSec) {
    var end = value;
    if (end <= state.startSec + VideoEditParams.eps) {
      end =
          (state.startSec + VideoEditParams.eps).clamp(0.0, maxSec).toDouble();
    }
    state = state.copyWith(endSec: end);
    _scheduleFrameFetch(end);
  }

  /// 滑块松手: 立即加载最终帧, 画面停留在该位置
  void commitScrub(double sec) {
    _frameThrottle?.cancel();
    _fetchFrame(sec);
  }

  /// 重置为完整视频
  void reset() {
    state = state.copyWith(startSec: 0, endSec: state.durationSec);
    _fetchFrame(0);
  }

  /// 保存剪辑参数; 未剪辑时清除参数
  Future<void> save() async {
    final asset = state.asset;
    if (asset == null || state.saving) return;

    state = state.copyWith(saving: true);
    try {
      final params = VideoEditParams(
        durationSec: state.durationSec,
        startSec: state.startSec,
        endSec: state.endSec,
      ).toJson();
      await ref.read(mediaAssetListProvider.notifier).applyPatch(
            mediaId: asset.id,
            intent: params == null
                ? const MediaPatchIntent(clearEditParams: true)
                : MediaPatchIntent(editParams: params),
          );
    } finally {
      if (!_disposed) state = state.copyWith(saving: false);
    }
  }

  /// 节流取帧: 拖动期间最多约 8 次/秒请求后端
  void _scheduleFrameFetch(double sec) {
    _frameThrottle?.cancel();
    _frameThrottle = Timer(const Duration(milliseconds: 120), () {
      _fetchFrame(sec);
    });
  }

  /// 请求指定秒数的单帧画面 (序号防乱序覆盖)
  Future<void> _fetchFrame(double sec) async {
    final asset = state.asset;
    if (asset == null) return;

    final api = ref.read(apiClientManagerProvider);
    final serial = ++_frameReqSerial;
    try {
      final resp = await api.getBinary(
        ApiPath.galleryIdTypePath(asset.id, 'frame'),
        queryParams: {'sec': sec.toStringAsFixed(2)},
      );
      if (_disposed || serial != _frameReqSerial) return;
      state = state.copyWith(frameBytes: resp.data);
    } catch (_) {
      // 取帧失败静默: 保留上一帧画面, 不影响剪辑
    }
  }
}
