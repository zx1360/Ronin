import 'package:uuid/uuid.dart';

final uuid=Uuid();
// ----其他----
// 生成随机id
String generateId() {
  return uuid.v4();
}

// ----DateTime相关----
// 判断两个日期是否为同一天
bool isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

// 生成精确到天的DateTime
DateTime getTodayDate() {
  final today = DateTime.now();
  return DateTime(today.year, today.month, today.day);
}

// ----文件相关----
// 去除非法目录字符.
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
