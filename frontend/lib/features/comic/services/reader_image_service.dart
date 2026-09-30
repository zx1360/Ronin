/// 漫画阅读页的图像拼接与裁剪（纯函数、无状态，便于单测）。
///
/// 纵向长图由若干图片段拼成：段宽度对齐后逐段纵向合成，最后编码成 PNG。
/// 选区裁剪只做"显示坐标 → 原图像素"的换算，实际裁剪由调用方完成。
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// 把已解码的图片段按首段宽度对齐后纵向拼成一张 PNG。
Uint8List mergeSegmentsToPng(List<img.Image> segments) {
  if (segments.isEmpty) {
    throw const ReaderImageException('没有可合并的图片内容');
  }

  final targetWidth = segments.first.width;
  final normalized = <img.Image>[];
  int totalHeight = 0;
  for (final segment in segments) {
    final normalizedSegment = segment.width == targetWidth
        ? segment
        : img.copyResize(segment, width: targetWidth);
    normalized.add(normalizedSegment);
    totalHeight += normalizedSegment.height;
  }

  final merged = img.Image(width: targetWidth, height: totalHeight);
  int currentY = 0;
  for (final segment in normalized) {
    img.compositeImage(merged, segment, dstX: 0, dstY: currentY);
    currentY += segment.height;
  }
  return Uint8List.fromList(img.encodePng(merged));
}

/// 解码图片字节；失败时抛出带来源路径的异常。
///
/// 只判 null 不够：个别格式的解码器（如 PSD）在数据被截断时会直接抛越界错误。
img.Image decodeImageOrThrow(Uint8List bytes, String source) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    throw ReaderImageException('图片解码失败: $source');
  }
  if (decoded == null) {
    throw ReaderImageException('图片解码失败: $source');
  }
  return decoded;
}

/// 选区在某张图片上需要保留的显示区间（相对该图顶部的显示像素）。
class CropSegment {
  const CropSegment({
    required this.imageIndex,
    required this.displayTop,
    required this.displayBottom,
  });

  final int imageIndex;
  final double displayTop;
  final double displayBottom;
}

/// 计算 [startOffset, endOffset] 选区覆盖到的每张图片及其保留区间。
///
/// [imageOffsets] 是各图片在长图中的显示顶部偏移（长度 = 图片数 + 1）。
List<CropSegment> collectCropSegments({
  required List<double> imageOffsets,
  required double startOffset,
  required double endOffset,
}) {
  if (imageOffsets.length < 2) return const [];

  final maxOffset = imageOffsets.last;
  final clampedStart = startOffset.clamp(0.0, maxOffset).toDouble();
  final clampedEnd = endOffset.clamp(0.0, maxOffset).toDouble();
  if (clampedEnd <= clampedStart) return const [];

  final result = <CropSegment>[];
  for (int i = 0; i < imageOffsets.length - 1; i++) {
    final imageTop = imageOffsets[i];
    final imageBottom = imageOffsets[i + 1];
    final overlapTop = max(imageTop, clampedStart);
    final overlapBottom = min(imageBottom, clampedEnd);
    if (overlapBottom <= overlapTop) continue;
    result.add(
      CropSegment(
        imageIndex: i,
        displayTop: overlapTop - imageTop,
        displayBottom: overlapBottom - imageTop,
      ),
    );
  }
  return result;
}

/// 阅读页图像处理的可读错误（对用户直接展示）。
class ReaderImageException implements Exception {
  const ReaderImageException(this.message);

  final String message;

  @override
  String toString() => message;
}
