// ----文件相关----
// 去除非法目录字符.
import 'dart:math';

String sanitizeDirectoryName(String input) {
  const invalidChars = r'<>:"/\|?*';
  final regex = RegExp('[$invalidChars]');
  return input.replaceAll(regex, '');
}

// 提取文件扩展名
String getFileExtension(String filePath) {
  int lastDotIndex = filePath.lastIndexOf('.');
  if (lastDotIndex != -1 && lastDotIndex < filePath.length - 1) {
    return filePath.substring(lastDotIndex + 1).toLowerCase();
  }
  return '';
}

// 生成随机文件名
String generateFileName() {
  final timestamp = DateTime.now().millisecondsSinceEpoch.toRadixString(16);
  final random = Random().nextInt(0x10000).toRadixString(16).padLeft(4, '0');
  return timestamp + random;
}