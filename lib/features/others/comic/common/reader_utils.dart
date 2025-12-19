import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/comic/models/chapter_info.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

/// 计算章节的有效图片数量（优先使用声明数量，其次使用列表长度）
int effectiveImageCount(ChapterInfo chapter) {
  final count = chapter.imageCount;
  if (count > 0) return count;
  return chapter.images.length;
}

/// 根据当前进度计算 Slider 值（少于两张时返回 -1 以隐藏控件）
double sliderValue(int currentIndex, int totalCount) {
  if (totalCount <= 1) return -1;
  return currentIndex / (totalCount - 1);
}

/// 解析图片的访问地址
String resolveImageUrl(Map<String, dynamic> image, bool isLocal, WidgetRef ref) {
  if (isLocal) return image['path'] as String;
  final baseUrl = ref.read(apiClientManagerProvider).baseUrl;
  return "$baseUrl/static/${image['path']}";
}

/// 解析为 ImageProvider，供翻页阅读模式使用
ImageProvider resolveImageProvider(
  Map<String, dynamic> image,
  bool isLocal,
  WidgetRef ref,
) {
  if (isLocal) {
    return FileImage(File(image['path'] as String));
  }
  final baseUrl = ref.read(apiClientManagerProvider).baseUrl;
  return NetworkImage("$baseUrl/static/${image['path']}");
}

/// 计算图片在指定最大宽度下的显示高度（宽度异常时回退为等于宽度）
double computeImageHeight(Map<String, dynamic> image, double maxWidth) {
  final width = image['width'];
  if (width is num && width > 0) {
    return (image['height'] as num) * (maxWidth / width);
  }
  return maxWidth;
}

/// 计算列表中每张图片的累计偏移量（用于快速定位滚动位置）
List<double> computeImageOffsets(List<Map<String, dynamic>> images, double maxWidth) {
  final offsets = <double>[];
  double current = 0.0;
  for (final img in images) {
    offsets.add(current);
    current += computeImageHeight(img, maxWidth);
  }
  offsets.add(current); // 最后一张底部位置，便于区间计算
  return offsets;
}
