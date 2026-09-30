import 'dart:io';

import 'package:image_size_getter/file_input.dart';
import 'package:image_size_getter/image_size_getter.dart';

// 按序获取该目录下所有图片路径和宽高信息.
Future<List<Map<String, dynamic>>> scanImages(Directory chapterDir) async {
  final imageFiles = <(int index, File file)>[];
  // 1. 遍历目录下一层文件，筛选图片并解析序号
  await for (final entity in chapterDir.list(followLinks: false)) {
    if (entity is File) {
      final name = entity.path.split(Platform.pathSeparator).last;
      final match = RegExp(
        r'^(\d+)\.(jpg|jpeg|png|gif|bmp|webp)$',
        caseSensitive: false,
      ).firstMatch(name);
      if (match != null) {
        imageFiles.add((int.parse(match.group(1)!), entity));
      }
    }
  }

  // 2. 按序号升序排序
  imageFiles.sort((a, b) => a.$1.compareTo(b.$1));

  // 3. 获取图片宽高
  final List<Map<String, dynamic>> result = [];
    for (final item in imageFiles) {
      final (_, file) = item;
      try {
        // 使用 image_size_getter 高效获取尺寸
        // 它会自动识别文件类型并只读取头部信息
        final size = ImageSizeGetter.getSizeResult(FileInput(file)).size;
        result.add({
          'path': file.path,
          'width': size.width,
          'height': size.height,
        });
      } catch (e) {
        // 如果文件损坏或格式不支持，会抛出异常，这里选择忽略
        // print('Failed to get size for ${file.path}: $e');
      }
    }

    return result;
}
