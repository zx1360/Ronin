/// 主窗口几何信息：普通状态下的尺寸 + 是否最大化。
///
/// 只存尺寸不存位置：多显示器拔插后恢复旧坐标容易把窗口丢到屏幕外，
/// 而尺寸越界只是观感问题，可以在读取时直接钳制。
class WindowGeometry {
  final double width;
  final double height;
  final bool maximized;

  const WindowGeometry({
    required this.width,
    required this.height,
    required this.maximized,
  });

  static const double defaultWidth = 1024;
  static const double defaultHeight = 688;
  // 低于最小尺寸时侧边导航 + 页面内容会互相挤压；上限用于拦掉磁盘上的离谱值。
  static const double minWidth = 960;
  static const double minHeight = 640;
  static const double maxWidth = 10000;
  static const double maxHeight = 10000;

  factory WindowGeometry.defaults() {
    return const WindowGeometry(
      width: defaultWidth,
      height: defaultHeight,
      maximized: false,
    );
  }

  factory WindowGeometry.fromJson(Map<String, dynamic> json) {
    return WindowGeometry(
      width: _clampDimension(json['width'], minWidth, maxWidth, defaultWidth),
      height: _clampDimension(
        json['height'],
        minHeight,
        maxHeight,
        defaultHeight,
      ),
      maximized: json['maximized'] == true,
    );
  }

  WindowGeometry copyWith({double? width, double? height, bool? maximized}) {
    return WindowGeometry(
      width: width ?? this.width,
      height: height ?? this.height,
      maximized: maximized ?? this.maximized,
    );
  }

  Map<String, dynamic> toJson() {
    return {'width': width, 'height': height, 'maximized': maximized};
  }

  /// 文件可能被手工改成非数字/NaN/负数：非法值退回默认值，越界值钳到合法区间。
  static double _clampDimension(
    Object? raw,
    double min,
    double max,
    double fallback,
  ) {
    final value = raw is num ? raw.toDouble() : double.tryParse('${raw ?? ''}');
    if (value == null || !value.isFinite) {
      return fallback;
    }
    return value.clamp(min, max).toDouble();
  }
}
