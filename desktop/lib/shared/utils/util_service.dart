import 'dart:math';

// 辅助函数：判断两个日期是否为同一天（忽略时间）
bool isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

// 生成精确到天的DateTime
DateTime getTodayDate() {
  final today = DateTime.now();
  return DateTime(today.year, today.month, today.day);
}

// 生成随机id
String generateId() {
  final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
  final random = Random().nextInt(9000) + 1000;
  return '$timestamp$random';
}

// 去除非法目录字符.
String sanitizeDirectoryName(String input) {
  const invalidChars = r'<>:"/\|?*';

  final regex = RegExp('[$invalidChars]');

  return input.replaceAll(regex, '');
}
