
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
String getTodayDateString() {
  final today = getTodayDate();
  return '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
}
