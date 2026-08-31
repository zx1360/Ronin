import 'package:uuid/uuid.dart';

final uuid = Uuid();
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

// 规整为"精确到天"的本地 DateTime（丢弃时分秒），保证比较/序列化语义一致
DateTime dateOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

// 生成精确到天的DateTime
DateTime getTodayDate() {
  final today = DateTime.now();
  return DateTime(today.year, today.month, today.day);
}

String getTodayDateString() {
  final today = getTodayDate();
  return '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
}
