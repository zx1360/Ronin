import 'dart:math';

class Util {
  // 辅助函数：判断两个日期是否为同一天（忽略时间）
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
  // 生成随机id
  static String generateId(){
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final random = Random().nextInt(9000)+1000;
    return '$timestamp$random';
  }
}