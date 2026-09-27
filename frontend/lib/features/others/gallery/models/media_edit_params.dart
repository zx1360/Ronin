import 'dart:convert';

/// 媒体 edit_params 契约的唯一实现
///
/// edit_params 是一段 JSON 文本, 由服务端按 `type` 分派应用:
/// - image: `{"type":"image","rotation":int,"crop_left":int,...}` (裁切坐标为原图像素)
/// - video: `{"type":"video","trim_start_sec":double,"trim_end_sec":double,"duration":double}`
///   (trim_end_sec <= 0 表示"到结尾"; 旧版按帧记录, 读取时按 fps 折算为秒)

/// 图片编辑参数
class ImageEditParams {
  const ImageEditParams({
    this.rotation = 0,
    this.cropLeft = 0,
    this.cropTop = 0,
    this.cropRight = 0,
    this.cropBottom = 0,
    this.hasCropFields = false,
  });

  /// 旋转角度 (0/90/180/270)
  final int rotation;

  /// 裁切区域 (原图像素坐标)
  final double cropLeft;
  final double cropTop;
  final double cropRight;
  final double cropBottom;

  /// 原 JSON 中是否带有裁切字段 (用于区分"未裁切"与"裁切到全图")
  final bool hasCropFields;

  /// 解析 edit_params; 非图片类型或无法解析时返回 null
  static ImageEditParams? tryParse(String? raw) {
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic> || json['type'] != 'image') return null;
      return ImageEditParams(
        rotation: (json['rotation'] as int? ?? 0) % 360,
        cropLeft: (json['crop_left'] as num?)?.toDouble() ?? 0,
        cropTop: (json['crop_top'] as num?)?.toDouble() ?? 0,
        cropRight: (json['crop_right'] as num?)?.toDouble() ?? 0,
        cropBottom: (json['crop_bottom'] as num?)?.toDouble() ?? 0,
        hasCropFields: json['crop_left'] != null,
      );
    } catch (_) {
      return null;
    }
  }

  /// 生成 edit_params JSON; [includeCrop] 为 false 时只写旋转角度
  String toJson({required bool includeCrop}) {
    final map = <String, dynamic>{'type': 'image', 'rotation': rotation};
    if (includeCrop) {
      map['crop_left'] = cropLeft.round();
      map['crop_top'] = cropTop.round();
      map['crop_right'] = cropRight.round();
      map['crop_bottom'] = cropBottom.round();
    }
    return jsonEncode(map);
  }
}

/// 视频剪辑参数
class VideoEditParams {
  const VideoEditParams({
    required this.durationSec,
    this.startSec = 0,
    this.endSec = 0,
  });

  /// 视频总时长 (秒)
  final double durationSec;

  /// 剪辑起止秒数
  final double startSec;
  final double endSec;

  /// 容差: 低于该值视为"从头/到结尾", 避免浮点噪声
  static const double eps = 0.05;

  /// 从已有 edit_params 解析剪辑区间, 并收敛到 [0, durationSec]
  static VideoEditParams parse(String? raw, {required double durationSec}) {
    double startSec = 0;
    double endSec = durationSec;
    if (raw != null) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        if (json['type'] == 'video') {
          final s = (json['trim_start_sec'] as num?)?.toDouble();
          final e = (json['trim_end_sec'] as num?)?.toDouble();
          if (s != null && s > 0) startSec = s;
          if (e != null && e > 0) endSec = e;
          // 旧版帧数协议作为后备
          if ((s == null || s <= 0) && json['trim_start_frame'] is int) {
            final fps = (json['fps'] as num?)?.toDouble() ?? 30.0;
            startSec = (json['trim_start_frame'] as int) / (fps > 0 ? fps : 30);
          }
          if ((e == null || e <= 0) && json['trim_end_frame'] is int) {
            final fps = (json['fps'] as num?)?.toDouble() ?? 30.0;
            final f = json['trim_end_frame'] as int;
            if (f > 0) endSec = f / (fps > 0 ? fps : 30);
          }
        }
      } catch (_) {}
    }
    if (startSec < 0) startSec = 0;
    if (endSec > durationSec) endSec = durationSec;
    if (endSec <= startSec + eps) endSec = durationSec;
    return VideoEditParams(
      durationSec: durationSec,
      startSec: startSec,
      endSec: endSec,
    );
  }

  /// 是否实际发生了剪辑
  bool get hasTrim => startSec > eps || endSec < durationSec - eps;

  /// 生成 edit_params JSON; 无剪辑时返回 null (交由调用方清除参数)
  String? toJson() {
    if (!hasTrim) return null;
    return jsonEncode(<String, dynamic>{
      'type': 'video',
      'trim_start_sec': startSec,
      // 到结尾时传 0 (后端语义: <=0 表示到结尾)
      'trim_end_sec': endSec < durationSec - eps ? endSec : 0,
      'duration': durationSec,
    });
  }
}

/// 解析 edit_params 生成人类可读的编辑提示; 返回 null 表示没有有效编辑信息
String? describeEditParams(String? raw) {
  if (raw == null) return null;
  try {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final type = json['type'] as String?;
    if (type == 'image') {
      final params = ImageEditParams.tryParse(raw);
      if (params == null) return null;
      final parts = <String>[];
      if (params.rotation != 0) parts.add('旋转${params.rotation}°');
      if (params.hasCropFields) parts.add('裁剪中');
      return parts.isEmpty ? null : '编辑: ${parts.join(' · ')}';
    } else if (type == 'video') {
      final start = (json['trim_start_sec'] as num?)?.toDouble();
      final end = (json['trim_end_sec'] as num?)?.toDouble();
      final parts = <String>[];
      if (start != null && start > 0) parts.add(_formatSeconds(start));
      if (end != null && end > 0) parts.add(_formatSeconds(end));
      return parts.isEmpty ? null : '剪辑: ${parts.join(' → ')}';
    }
  } catch (_) {}
  return null;
}

String _formatSeconds(double sec) {
  final m = (sec / 60).floor();
  final s = (sec % 60).floor();
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}
