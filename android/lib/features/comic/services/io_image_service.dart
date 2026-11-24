import 'dart:io';

import 'package:image_size_getter/file_input.dart';
import 'package:image_size_getter/image_size_getter.dart';

final _pageName = RegExp(
  r'^(\d+)\.(jpg|jpeg|png|gif|bmp|webp)$',
  caseSensitive: false,
);

Future<List<Map<String, dynamic>>> scanImages(Directory chapterDir) async {
  final imageFiles = <(int index, File file)>[];
  await for (final entity in chapterDir.list(followLinks: false)) {
    if (entity is! File) continue;
    final name = entity.path.split(Platform.pathSeparator).last;
    final match = _pageName.firstMatch(name);
    if (match != null) {
      imageFiles.add((int.parse(match.group(1)!), entity));
    }
  }

  imageFiles.sort((a, b) => a.$1.compareTo(b.$1));

  final result = <Map<String, dynamic>>[];
  for (final (_, file) in imageFiles) {
    try {
      final size = ImageSizeGetter.getSizeResult(FileInput(file)).size;
      result.add({
        'path': file.path,
        'width': size.width,
        'height': size.height,
      });
    } catch (_) {
      // 跳过损坏或不支持的单页，继续恢复章节索引。
    }
  }
  return result;
}
