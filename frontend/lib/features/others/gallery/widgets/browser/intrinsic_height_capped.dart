part of '../../pages/medias_browser_page.dart';

/// 内禀高度限制组件
///
/// 将子组件的内禀高度和实际布局高度均限制在 `maxAspectRatio * width` 以内。
/// 用于 [IntrinsicHeight] 行布局中，防止极高的图片撑开整行。
/// `maxAspectRatio` 表示 `maxHeight / width` 的上限，例如 4.0 表示高度不超过宽度的 4 倍。
class _IntrinsicHeightCapped extends SingleChildRenderObjectWidget {
  final double maxAspectRatio;

  const _IntrinsicHeightCapped({
    required this.maxAspectRatio,
    required super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderIntrinsicHeightCapped(maxAspectRatio: maxAspectRatio);
  }

  @override
  void updateRenderObject(BuildContext context, _RenderIntrinsicHeightCapped renderObject) {
    renderObject.maxAspectRatio = maxAspectRatio;
  }
}

class _RenderIntrinsicHeightCapped extends RenderProxyBox {
  double maxAspectRatio;

  _RenderIntrinsicHeightCapped({required this.maxAspectRatio});

  @override
  double computeMinIntrinsicHeight(double width) {
    final childHeight = super.computeMinIntrinsicHeight(width);
    final cap = width * maxAspectRatio;
    return childHeight < cap ? childHeight : cap;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    final childHeight = super.computeMaxIntrinsicHeight(width);
    final cap = width * maxAspectRatio;
    return childHeight < cap ? childHeight : cap;
  }

  @override
  void performLayout() {
    if (child != null) {
      final width = constraints.maxWidth;
      final cap = width * maxAspectRatio;
      final effectiveMaxH = constraints.maxHeight.isFinite
          ? min(constraints.maxHeight, cap)
          : cap;
      child!.layout(
        constraints.copyWith(
          maxHeight: effectiveMaxH.clamp(constraints.minHeight, double.infinity),
        ),
        parentUsesSize: true,
      );
      size = Size(constraints.maxWidth, child!.size.height);
    } else {
      size = Size(constraints.maxWidth, constraints.minHeight);
    }
  }
}
