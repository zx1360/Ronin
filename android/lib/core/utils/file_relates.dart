import 'dart:math';

String sanitizeDirectoryName(String input) {
  const invalidChars = r'<>:"/\|?*';
  final regex = RegExp('[$invalidChars]');
  return input.replaceAll(regex, '');
}

String getFileExtension(String filePath) {
  int lastDotIndex = filePath.lastIndexOf('.');
  if (lastDotIndex != -1 && lastDotIndex < filePath.length - 1) {
    return filePath.substring(lastDotIndex + 1).toLowerCase();
  }
  return '';
}

String generateFileName() {
  final timestamp = DateTime.now().millisecondsSinceEpoch.toRadixString(16);
  final random = Random().nextInt(0x10000).toRadixString(16).padLeft(4, '0');
  return timestamp + random;
}